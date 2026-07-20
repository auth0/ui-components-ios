import Auth0
import Combine
import Foundation

/// View model for email and phone number enrollment.
///
/// Manages the enrollment process for email and SMS authentication methods,
/// including country code selection for phone numbers, input validation,
/// and initiation of the enrollment flow.
@MainActor
final class EmailPhoneEnrollmentViewModel: ObservableObject, ErrorMessageHandler {
    
    // MARK: - Properties
    private let startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable
    private let startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable
    private let dependencies: Auth0UniversalComponentsSDKInitializer
    private let errorHandler = ErrorHandler()
    private let type: AuthMethodType
    
    // MARK: - Published Properties
    @Published var errorMessage: String?
    @Published var selectedCountry: Country? = Country(name: "United States", code: "+1",
                                                                         flag: "🇺🇸")
    @Published var phoneNumber: String = ""
    @Published var email: String = ""
    @Published var isPickerVisible = false
    @Published var apiCallInProgress = false
    @Published var otpSheetConfig: OTPSheetConfig?
    
    // MARK: - Computed Properties
    var isButtonEnabled: Bool {
        type == .email ? !email.isEmpty : !phoneNumber.isEmpty
    }
    

    var isPhoneAuthMethod: Bool {
        type == .sms
    }

    var title: String {
        if type == .email {
            "Enter your email address"
        } else {
            "Enter your phone number"
        }
    }

    // MARK: - Init
    init(startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable = StartPhoneEnrollmentUseCase(),
         startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable = StartEmailEnrollmentUseCase(),
         type: AuthMethodType,
         dependencies: Auth0UniversalComponentsSDKInitializer = .shared) {
        self.startPhoneEnrollmentUseCase = startPhoneEnrollmentUseCase
        self.startEmailEnrollmentUseCase = startEmailEnrollmentUseCase
        self.dependencies = dependencies
        self.type = type
    }

    // MARK: - Helper methods
    func startEnrollment() async {
        apiCallInProgress = true
        errorMessage = nil
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                audience: dependencies.audience,
                scope: "openid create:me:authentication_methods"
            )
            if type == .sms, let phoneNumber = selectedCountry?.code.appending(phoneNumber) {
                let startPhoneEnrollmentRequest = StartPhoneEnrollmentRequest(
                    token: apiCredentials.accessToken,
                    domain: dependencies.domain,
                    phoneNumber: phoneNumber
                )
                let phoneEnrollmentChallenge = try await startPhoneEnrollmentUseCase.execute(
                    request: startPhoneEnrollmentRequest
                )
                apiCallInProgress = false
                otpSheetConfig = OTPSheetConfig(
                    type: .sms,
                    emailOrPhoneNumber: phoneNumber,
                    totpEnrollmentChallenge: nil,
                    phoneEnrollmentChallenge: phoneEnrollmentChallenge,
                    emailEnrollmentChallenge: nil
                )
            } else if type == .email {
                let startEmailEnrollmentRequest = StartEmailEnrollmentRequest(
                    token: apiCredentials.accessToken,
                    domain: dependencies.domain,
                    email: email
                )
                let emailEnrollmentChallenge = try await startEmailEnrollmentUseCase.execute(
                    request: startEmailEnrollmentRequest
                )
                apiCallInProgress = false
                otpSheetConfig = OTPSheetConfig(
                    type: .email,
                    emailOrPhoneNumber: email,
                    totpEnrollmentChallenge: nil,
                    phoneEnrollmentChallenge: nil,
                    emailEnrollmentChallenge: emailEnrollmentChallenge
                )
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

    func handle(error: Error, scope: String, retryCallback: @escaping () -> Void) async {
        await errorHandler.handle(error: error, scope: scope, handler: self, retryCallback: retryCallback)
    }

}
