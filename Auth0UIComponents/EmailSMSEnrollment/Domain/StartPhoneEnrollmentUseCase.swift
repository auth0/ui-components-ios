import Auth0
import Foundation

/// Request parameters for initiating phone enrollment.
struct StartPhoneEnrollmentRequest {
    let token: String
    let domain: String
    let phoneNumber: String
    let preferredAuthenticationMethod: PreferredAuthenticationMethod = .sms
}

/// Protocol for initiating phone enrollment.
protocol StartPhoneEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartPhoneEnrollmentRequest) async throws -> PhoneEnrollmentChallenge
}

/// Use case for initiating phone enrollment and retrieving enrollment challenge.
struct StartPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(request: StartPhoneEnrollmentRequest) async throws -> PhoneEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollPhone(phoneNumber: request.phoneNumber, preferredAuthenticationMethod: request.preferredAuthenticationMethod)
            .start()
    }
}
