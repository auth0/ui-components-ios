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
final class PasskeysEnrollmentViewModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ErrorViewModelHandler {

    private let startPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable
    private let confirmPasskeyEnrollmentUseCase: ConfirmPasskeyEnrollmentUseCaseable
    private let dependencies: Auth0UIComponentsSDKInitializer
    private var passkeyChallenge: PasskeyEnrollmentChallenge? = nil
    private var delegate: RefreshAuthDataProtocol?
    private let errorHandler = ErrorHandler()
    @Published var showLoader: Bool = false
    @Published var errorViewModel: ErrorScreenViewModel? = nil

    init(startPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable = StartPasskeyEnrollmentUseCase(),
         confirmPasskeyEnrollmentUseCase: ConfirmPasskeyEnrollmentUseCaseable = ConfirmPasskeyEnrollmentUseCase(),
         dependencies: Auth0UIComponentsSDKInitializer = .shared,
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
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "create:me:authentication_methods")
            let startPasskeysEnrollmentRequest = await StartPasskeyEnrollmentRequest(token: apiCredentials.accessToken,
                                                                                     domain: dependencies.domain,
                                                                                     userIdentityId: dependencies.passkeyConfiguration.userIdentityId,
                                                                                     connection: dependencies.passkeyConfiguration.connection)
            passkeyChallenge = try await startPasskeyEnrollmentUseCase.execute(request: startPasskeysEnrollmentRequest)
            enrollPasskey()
        } catch {
            await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                Task {
                    await self?.startEnrollment()
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        Task {
            switch authorization.credential {
            case let newPasskey as ASAuthorizationPlatformPublicKeyCredentialRegistration:
                if let passkeyChallenge {
                    do {
                        showLoader = true
                        let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                        let confirmPasskeyEnrollmentRequest = ConfirmPasskeyEnrollmentRequest(passkey: newPasskey,
                                                            token: apiCredentials.accessToken,
                                                            domain: dependencies.domain,
                                                            challenge: passkeyChallenge)
                        _ = try await confirmPasskeyEnrollmentUseCase.execute(request: confirmPasskeyEnrollmentRequest)
                        delegate?.refreshAuthData()
                        await NavigationStore.shared.push(.filteredAuthListScreen(type: .passkey, authMethods: []))
                    } catch {
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

        if let authError = error as? ASAuthorizationError, authError.code != .canceled {
            errorViewModel = Auth0UIComponentError.unknown().errorViewModel { [weak self] in
                Task {
                    await self?.startEnrollment()
                }
            }
        } else {
            Task { [weak self] in
                await self?.handle(
                    error: error,
                    scope: "openid create:me:authentication_methods",
                    retryCallback: {
                        Task {
                            await self?.startEnrollment()
                        }
                    }
                )
            }
        }
    }

    func handle(error: Error, scope: String, retryCallback: @escaping () -> Void) async {
        await errorHandler.handle(error: error, scope: scope, handler: self, retryCallback: retryCallback)
    }
}
