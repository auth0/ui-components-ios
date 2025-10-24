import Auth0
import Combine
import Foundation

@MainActor
final class EmailPhoneEnrollmentViewModel: ObservableObject {
    private let startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable
    private let startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable
    private let dependencies: Dependencies
    @Published var errorMessage: String?
    @Published var selectedCountry: CountryModel? = CountryModel.init(countryCode: "+1",
                                                                         countryName: "United States",
                                                                         countryShortName: "US",
                                                                         countryFlag: "🇺🇸")
    @Published var phoneNumber: String = ""
    @Published var email: String = ""
    @Published var isPickerVisible = false
    private let type: AuthMethodType

    init(startPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable = StartPhoneEnrollmentUseCase(),
         startEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable = StartEmailEnrollmentUseCase(),
         type: AuthMethodType,
         dependencies: Dependencies = .shared) {
        self.startPhoneEnrollmentUseCase = startPhoneEnrollmentUseCase
        self.startEmailEnrollmentUseCase = startEmailEnrollmentUseCase
        self.dependencies = dependencies
        self.type = type
    }
    
    func startEnrollment() async {
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "create:me:authentication_methods")
            if type == .sms, let phoneNumber = selectedCountry?.countryCode?.appending(phoneNumber) {
                let phoneEnrollmentChallenge = try await startPhoneEnrollmentUseCase.execute(request: StartPhoneEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, phoneNumber: phoneNumber))
                await NavigationStore.shared.push(.otpScreen(type: .sms, emailOrPhoneNumber: phoneNumber, phoneEnrollmentChallenge: phoneEnrollmentChallenge))
            } else if type == .email {
                let emailEnrollmentChallenge = try await startEmailEnrollmentUseCase.execute(request: StartEmailEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, email: email))
                await NavigationStore.shared.push(.otpScreen(type: .email, emailOrPhoneNumber: email, emailEnrollmentChallenge: emailEnrollmentChallenge))
            }
        } catch {
            errorMessage = error.localizedDescription
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
}
