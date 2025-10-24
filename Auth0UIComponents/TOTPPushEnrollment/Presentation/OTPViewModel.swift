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
    private let dependencies: Dependencies
    private let type: AuthMethodType
    private let emailOrPhoneNumber: String?
    @Published var errorMessage: String?

    init(startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable = StartPhoneEnrollmentUseCase(),
         confirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCaseable = ConfirmPhoneEnrollmentUseCase(),
         startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable = StartEmailEnrollmentUseCase(),
         confirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCaseable = ConfirmEmailEnrollmentUseCase(),
         confirmTOTPEnrollmentUSeCase: ConfirmTOTPEnrollmentUseCaseable = ConfirmTOTPEnrollmentUseCase(),
         dependencies: Dependencies = .shared,
         totpEnrollmentChallenge: TOTPEnrollmentChallenge?,
         emailEnrollmentChallenge: EmailEnrollmentChallenge?,
         phoneEnrollmentChallenge: PhoneEnrollmentChallenge?,
         type: AuthMethodType,
         emailOrPhoneNumber: String? = nil
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
    }

    func confirmEnrollment(with code: String) {
        Task {
            errorMessage = nil
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                if type == .totp, let totpEnrollmentChallenge {
                    _ = try await confirmTOTPEnrollmentUseCase.execute(request: ConfirmTOTPEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: totpEnrollmentChallenge.authenticationId, authSession: totpEnrollmentChallenge.authenticationSession, otpCode: code))
                }
                if type == .email, let emailEnrollmentChallenge {
                    _ = try await confirmEmailEnrollmentUseCase.execute(request: ConfirmEmailEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: emailEnrollmentChallenge.authenticationId, authSession: emailEnrollmentChallenge.authenticationSession, otpCode: code))
                }
                if type == .sms, let phoneEnrollmentChallenge {
                    _ = try await confirmPhoneEnrollmentUseCase.execute(request: ConfirmPhoneEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: phoneEnrollmentChallenge.authenticationId, authSession: phoneEnrollmentChallenge.authenticationSession, otpCode: code))
                }
                await NavigationStore.shared.push(.filteredAuthListScreen(type: type, authMethods: []))
            } catch {
                await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                    self?.confirmEnrollment(with: code)
                }
            }
        }
    }

    func restartEnrollment() {
        Task {
            if let emailOrPhoneNumber {
                do {
                    let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                    if type == .email {
                        phoneEnrollmentChallenge = try await
                        startPhoneEnrollmentUseCase.execute(request: StartPhoneEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, phoneNumber: emailOrPhoneNumber))
                    } else {
                        emailEnrollmentChallenge = try await startEmailEnrollmentUseCase.execute(request: StartEmailEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, email: emailOrPhoneNumber))
                    }
                } catch {
                    await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                        self?.restartEnrollment()
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
                    let credentials = try await Auth0.webAuth()
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
                // TODO: handle error case
//                errorViewModel = uiComponentError.errorViewModel(completion: {
//                    retryCallback()
//                })
            }
        } else if let error  = error as? MyAccountError {
            let uiComponentError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
            // TODO: handle error case
//            errorViewModel = uiComponentError.errorViewModel(completion: {
//                retryCallback()
//            })
        }
    }
}
