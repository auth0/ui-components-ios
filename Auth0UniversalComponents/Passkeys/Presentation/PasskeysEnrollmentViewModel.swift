import Auth0
import Combine
import AuthenticationServices

/// View model for passkey enrollment.
///
/// Manages the complete passkey enrollment flow including:
/// - Requesting enrollment challenges from Auth0
/// - Integrating with the platform's credential provider (ASAuthorizationController)
/// - Confirming enrollment with newly created passkeys
///
/// Availability: Requires iOS 16.6, macOS 13.5, or visionOS 1.0+
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
@MainActor
final class PasskeysEnrollmentViewModel: NSObject,
                                        ObservableObject,
                                        ASAuthorizationControllerDelegate,
                                        ErrorViewModelHandler {

    // MARK: - Properties
    private let startPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable
    private let confirmPasskeyEnrollmentUseCase: ConfirmPasskeyEnrollmentUseCaseable
    private let dependencies: Auth0UniversalComponentsSDKInitializer
    private var passkeyChallenge: PasskeyEnrollmentChallenge?
    private var delegate: RefreshAuthDataProtocol?
    private let errorHandler = ErrorHandler()
    
    // MARK: - Published properties
    @Published var showLoader: Bool = false
    @Published var errorViewModel: ErrorScreenViewModel?
    @Published var navigationRoute: Route?

    // MARK: - Init
    init(startPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable = StartPasskeyEnrollmentUseCase(),
         confirmPasskeyEnrollmentUseCase: ConfirmPasskeyEnrollmentUseCaseable = ConfirmPasskeyEnrollmentUseCase(),
         dependencies: Auth0UniversalComponentsSDKInitializer = .shared,
         delegate: RefreshAuthDataProtocol?) {
        self.startPasskeyEnrollmentUseCase = startPasskeyEnrollmentUseCase
        self.confirmPasskeyEnrollmentUseCase = confirmPasskeyEnrollmentUseCase
        self.dependencies = dependencies
        self.delegate = delegate
    }

    func enrollPasskey() {
        if let passkeyChallenge {
            let credentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: passkeyChallenge.relyingPartyId
            )
            let request = credentialProvider.createCredentialRegistrationRequest(
                challenge: passkeyChallenge.challengeData,
                name: passkeyChallenge.userName,
                userID: passkeyChallenge.userId
            )

            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = self
            authController.performRequests()
        }
    }

    func startEnrollment() async {
        showLoader = true
        errorViewModel = nil
        TelemetryManager.shared.trackScreenView("passkey_enrollment")
        TelemetryManager.shared.trackFlow("enrollment_started", factorType: "passkey")
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                audience: dependencies.audience,
                scope: "create:me:authentication_methods"
            )
            let startPasskeysEnrollmentRequest = await StartPasskeyEnrollmentRequest(
                token: apiCredentials.accessToken,
                domain: dependencies.domain,
                userIdentityId: dependencies.passkeyConfiguration.userIdentityId,
                connection: dependencies.passkeyConfiguration.connection
            )
            passkeyChallenge = try await startPasskeyEnrollmentUseCase.execute(
                request: startPasskeysEnrollmentRequest
            )
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            TelemetryManager.shared.trackApiCall("start_passkey_enrollment", durationMs: durationMs, status: .success)
            showLoader = false
            enrollPasskey()
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            TelemetryManager.shared.trackApiCall("start_passkey_enrollment", durationMs: durationMs, status: .failure, errorType: String(describing: Swift.type(of: error)))
            TelemetryManager.shared.trackFlow("enrollment_failed", factorType: "passkey", status: .failure)
            showLoader = false
            errorViewModel = Auth0UIComponentError.unknown(message: error.localizedDescription).errorViewModel { [weak self] in
                Task { await self?.startEnrollment() }
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task {
            switch authorization.credential {
            case let newPasskey as ASAuthorizationPlatformPublicKeyCredentialRegistration:
                if let passkeyChallenge {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    do {
                        showLoader = true
                        let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                            audience: dependencies.audience,
                            scope: "openid create:me:authentication_methods"
                        )
                        let confirmPasskeyEnrollmentRequest = ConfirmPasskeyEnrollmentRequest(
                            passkey: newPasskey,
                            token: apiCredentials.accessToken,
                            domain: dependencies.domain,
                            challenge: passkeyChallenge
                        )
                        _ = try await confirmPasskeyEnrollmentUseCase.execute(request: confirmPasskeyEnrollmentRequest)
                        let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                        TelemetryManager.shared.trackApiCall("confirm_passkey_enrollment", durationMs: durationMs, status: .success)
                        TelemetryManager.shared.trackFlow("enrollment_completed", factorType: "passkey", status: .success)
                        delegate?.refreshAuthData()
                        navigationRoute = .filteredAuthListScreen(type: .passkey, authMethods: [], isPostEnrollment: true)
                    } catch {
                        let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                        TelemetryManager.shared.trackApiCall("confirm_passkey_enrollment", durationMs: durationMs, status: .failure, errorType: String(describing: Swift.type(of: error)))
                        TelemetryManager.shared.trackFlow("enrollment_failed", factorType: "passkey", status: .failure)
                        await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                            Task {
                                await self?.startEnrollment()
                            }
                        }
                    }
                }
            default:
                self.errorViewModel = Auth0UIComponentError.unknown().errorViewModel { [weak self] in
                    Task {
                        await self?.startEnrollment()
                    }
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        showLoader = false

        guard let authError = error as? ASAuthorizationError else {
            Task { [weak self] in
                await self?.handle(
                    error: error,
                    scope: "openid create:me:authentication_methods",
                    retryCallback: {
                        Task { await self?.startEnrollment() }
                    }
                )
            }
            return
        }

        switch authError.code {
        case .canceled:
            break
        case .failed:
            // Code 1004: platform rejected the request — most commonly a domain association
            // misconfiguration (entitlements webcredentials entry or AASA file on the server).
            errorViewModel = Auth0UIComponentError.unknown(message: authError.localizedDescription).errorViewModel { [weak self] in
                Task { await self?.startEnrollment() }
            }
        default:
            errorViewModel = Auth0UIComponentError.unknown().errorViewModel { [weak self] in
                Task { await self?.startEnrollment() }
            }
        }
    }

    func handle(error: Error, scope: String, retryCallback: @escaping () -> Void) async {
        await errorHandler.handle(error: error, scope: scope, handler: self, retryCallback: retryCallback)
    }
}
