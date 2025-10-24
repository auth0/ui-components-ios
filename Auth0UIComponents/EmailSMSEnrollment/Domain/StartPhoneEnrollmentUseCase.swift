import Auth0
import Foundation

struct StartPhoneEnrollmentRequest {
    let token: String
    let domain: String
    let phoneNumber: String
    let preferredAuthenticationMethod: PreferredAuthenticationMethod = .sms
}

protocol StartPhoneEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartPhoneEnrollmentRequest) async throws -> PhoneEnrollmentChallenge
}

struct StartPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(request: StartPhoneEnrollmentRequest) async throws -> PhoneEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain)
            .authenticationMethods
            .enrollPhone(phoneNumber: request.phoneNumber, preferredAuthenticationMethod: request.preferredAuthenticationMethod)
            .start()
    }
}
