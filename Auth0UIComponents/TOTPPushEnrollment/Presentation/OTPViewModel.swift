import Auth0
import Combine
import Foundation

@MainActor
final class OTPViewModel: ObservableObject {
    private let totpEnrollmentChallenge: TOTPEnrollmentChallenge?
    private var phoneEnrollmentChallenge: PhoneEnrollmentChallenge?
    private var emailEnrollmentChallenge: EmailEnrollmentChallenge?
    private let confirmTOTPEnrollmentUseCase: ConfirmTOTPEnrollmentUseCaseable
    private let startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable
    private let confirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCaseable
    private let startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable
    private let confirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCaseable
    private let dependencies: Auth0UIComponentsSDKInitializer
    private let type: AuthMethodType
    private let emailOrPhoneNumber: String?
    private weak var delegate: RefreshAuthDataProtocol?
    @Published var showLoader: Bool = false
    @Published var errorMessage: String?
    @Published var otpText: String = ""
    @Published var apiCallInProgress: Bool = false
    var buttonEnabled: Bool {
        otpText.count == 6
    }

    init(startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable = StartPhoneEnrollmentUseCase(),
         confirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCaseable = ConfirmPhoneEnrollmentUseCase(),
         startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable = StartEmailEnrollmentUseCase(),
         confirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCaseable = ConfirmEmailEnrollmentUseCase(),
         confirmTOTPEnrollmentUSeCase: ConfirmTOTPEnrollmentUseCaseable = ConfirmTOTPEnrollmentUseCase(),
         dependencies: Auth0UIComponentsSDKInitializer = .shared,
         totpEnrollmentChallenge: TOTPEnrollmentChallenge? = nil,
         emailEnrollmentChallenge: EmailEnrollmentChallenge? = nil,
         phoneEnrollmentChallenge: PhoneEnrollmentChallenge? = nil,
         type: AuthMethodType,
         emailOrPhoneNumber: String? = nil,
         delegate: RefreshAuthDataProtocol? = nil
    ) {
        self.dependencies = dependencies
        self.type = type
        self.emailOrPhoneNumber = emailOrPhoneNumber
        self.startPhoneEnrollmentUseCase = startPhoneEnrollmentUseCase
        self.confirmPhoneEnrollmentUseCase = confirmPhoneEnrollmentUseCase
        self.startEmailEnrollmentUseCase = startEmailEnrollmentUseCase
        self.confirmEmailEnrollmentUseCase = confirmEmailEnrollmentUseCase
        self.confirmTOTPEnrollmentUseCase = confirmTOTPEnrollmentUSeCase
        self.emailEnrollmentChallenge = emailEnrollmentChallenge
        self.phoneEnrollmentChallenge = phoneEnrollmentChallenge
        self.totpEnrollmentChallenge = totpEnrollmentChallenge
        self.delegate = delegate
    }

    func confirmEnrollment() async {
        apiCallInProgress = true
        errorMessage = nil
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
            if type == .totp, let totpEnrollmentChallenge {
                let confirmTOTPEnrollmentRequest = ConfirmTOTPEnrollmentRequest(token: apiCredentials.accessToken,
                                                                                domain: dependencies.domain,
                                                                                id: totpEnrollmentChallenge.authenticationId,
                                                                                authSession: totpEnrollmentChallenge.authenticationSession,
                                                                                otpCode: otpText)
                _ = try await confirmTOTPEnrollmentUseCase.execute(request: confirmTOTPEnrollmentRequest)
            }
            if type == .email, let emailEnrollmentChallenge {
                let confirmEmailEnrollmentRequest = ConfirmEmailEnrollmentRequest(token: apiCredentials.accessToken,
                                                                                  domain: dependencies.domain,
                                                                                  id: emailEnrollmentChallenge.authenticationId,
                                                                                  authSession: emailEnrollmentChallenge.authenticationSession,
                                                                                  otpCode: otpText)
                _ = try await confirmEmailEnrollmentUseCase.execute(request: confirmEmailEnrollmentRequest)
            }
            if type == .sms, let phoneEnrollmentChallenge {
                let confirmPhoneEnrollmentRequest = ConfirmPhoneEnrollmentRequest(token: apiCredentials.accessToken,
                                                                                  domain: dependencies.domain,
                                                                                  id: phoneEnrollmentChallenge.authenticationId,
                                                                                  authSession: phoneEnrollmentChallenge.authenticationSession,
                                                                                  otpCode: otpText)
                _ = try await confirmPhoneEnrollmentUseCase.execute(request: confirmPhoneEnrollmentRequest)
            }
            apiCallInProgress = false
            delegate?.refreshAuthData()
            await NavigationStore.shared.push(.filteredAuthListScreen(type: type, authMethods: []))
        } catch {
            apiCallInProgress = false
            await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                Task {
                    await self?.confirmEnrollment()
                }
            }
        }
    }

    func restartEnrollment() async {
        if let emailOrPhoneNumber {
            showLoader = true
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                if type == .sms {
                    phoneEnrollmentChallenge = try await
                    startPhoneEnrollmentUseCase.execute(request: StartPhoneEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, phoneNumber: emailOrPhoneNumber))
                } else {
                    let startEmailEnrollmentRequest = StartEmailEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, email: emailOrPhoneNumber)
                    emailEnrollmentChallenge = try await startEmailEnrollmentUseCase.execute(request: startEmailEnrollmentRequest)
                }
                showLoader = false
            } catch {
                showLoader = false
                await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                    Task {
                        await self?.restartEnrollment()
                    }
                }
            }
        }
    }

    var isEmailOrSMS: Bool {
        type == .sms || type == .email
    }
    
    var formattedEmailOrPhoneNumber: String {
        if let emailOrPhoneNumber {
            return emailOrPhoneNumber
        }
        return ""
    }
    
    var navigationTitle: String {
        switch type {
        case .totp:
            "Add an Authenticator"
        case .email:
            "Verify it’s you"
        case .sms:
            "Add Phone for SMS OTP"
        default:
            "Verify it's you"
        }
    }
    
    @MainActor func handle(error: Error,
                           scope: String,
                           retryCallback: @escaping () -> Void) async {
        if let error = error as? CredentialsManagerError {
            let uiComponentError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
            if case .mfaRequired = uiComponentError {
                do {
                    let credentials = try await Auth0.webAuth(clientId: dependencies.clientId,
                                                              domain: dependencies.domain,
                                                              session: dependencies.session)
                        .audience(dependencies.audience)
                        .scope(scope)
                        .start()
                    dependencies.tokenProvider.store(apiCredentials: APICredentials(from: credentials), for: dependencies.audience)
                    retryCallback()
                } catch  {
                    await handle(error: error,
                                 scope: scope,
                                 retryCallback: retryCallback)
                }
            } else {
                
            }
        } else if let error = error as? MyAccountError {
            if error.code == "invalid_grant" ||
                error.message.localizedStandardContains("invalid") ||
                error.message.localizedStandardContains("incorrect") {
                errorMessage = "Invalid passcode. Please try again."
            } else if error.message.localizedStandardContains("expired") {
                errorMessage = "Passcode expired. Please request a new one."
            } else if error.message.localizedStandardContains("rate") {
                errorMessage = "Too many attempts. Please try again later."
            } else {
                errorMessage = error.message
            }
        } else if let error = error as? WebAuthError {
            errorMessage = error.message
        }
    }
}
