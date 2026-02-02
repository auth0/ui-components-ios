import Auth0
import Foundation

/// Protocol for initiating email enrollment.
protocol StartEmailEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartEmailEnrollmentRequest)  async throws -> EmailEnrollmentChallenge
}

/// Request parameters for initiating email enrollment.
struct StartEmailEnrollmentRequest {
    let token: String
    let domain: String
    let email: String
}


/// Use case for initiating email enrollment and retrieving enrollment challenge.
struct StartEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    
    func execute(request: StartEmailEnrollmentRequest)  async throws -> EmailEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollEmail(emailAddress: request.email)
            .start()
    }
}
