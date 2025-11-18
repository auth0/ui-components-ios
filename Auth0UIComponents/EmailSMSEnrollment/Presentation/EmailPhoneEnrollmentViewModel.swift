import Auth0
import Combine
import Foundation

@MainActor
final class EmailPhoneEnrollmentViewModel: ObservableObject {
    private let startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable
    private let startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable
    private let dependencies: Auth0UIComponentsSDKInitializer
    @Published var errorMessage: String?
    @Published var selectedCountry: Country? = Country(name: "United States", code: "+1",
                                                                         flag: "🇺🇸")
    @Published var phoneNumber: String = ""
    @Published var email: String = ""
    @Published var isPickerVisible = false
    @Published var apiCallInProgress = false
    var isButtonEnabled: Bool {
        type == .email ? !email.isEmpty : !phoneNumber.isEmpty
    }
    private let type: AuthMethodType

    init(startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable = StartPhoneEnrollmentUseCase(),
         startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable = StartEmailEnrollmentUseCase(),
         type: AuthMethodType,
         dependencies: Auth0UIComponentsSDKInitializer = .shared) {
        self.startPhoneEnrollmentUseCase = startPhoneEnrollmentUseCase
        self.startEmailEnrollmentUseCase = startEmailEnrollmentUseCase
        self.dependencies = dependencies
        self.type = type
    }
    
    func startEnrollment() async {
        apiCallInProgress = true
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
            if type == .sms, let phoneNumber = selectedCountry?.code.appending(phoneNumber) {
                let phoneEnrollmentChallenge = try await startPhoneEnrollmentUseCase.execute(request: StartPhoneEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, phoneNumber: phoneNumber))
                apiCallInProgress = false
                await NavigationStore.shared.push(.otpScreen(type: .sms, emailOrPhoneNumber: phoneNumber, phoneEnrollmentChallenge: phoneEnrollmentChallenge))
            } else if type == .email {
                let emailEnrollmentChallenge = try await startEmailEnrollmentUseCase.execute(request: StartEmailEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, email: email))
                apiCallInProgress = false
                await NavigationStore.shared.push(.otpScreen(type: .email, emailOrPhoneNumber: email, emailEnrollmentChallenge: emailEnrollmentChallenge))
            }
        } catch {
            apiCallInProgress = false
            await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                Task {
                    await self?.startEnrollment()
                }
            }
        }
    }

    var isPhoneAuthMethod: Bool {
        type == .sms
    }

    var navigationTitle: String {
        if type == .email {
            "Add Email OTP"
        } else {
            "Add Phone for SMS OTP"
        }
    }

    var title: String {
        if type == .email {
            "Enter your email address"
        } else {
            "Enter your phone number"
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
                    await dependencies.tokenProvider.store(apiCredentials: APICredentials(from: credentials), for: dependencies.audience)
                    retryCallback()
                } catch  {
                    await handle(error: error,
                                 scope: scope,
                                 retryCallback: retryCallback)
                }
            } else {
                errorMessage = error.message
            }
        } else if let error  = error as? MyAccountError {
            errorMessage = error.message
        } else if let error = error as? WebAuthError {
            errorMessage = error.message
        }
    }

}
