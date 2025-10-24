import Auth0
import Foundation

protocol StartEmailEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartEmailEnrollmentRequest)  async throws -> EmailEnrollmentChallenge
}

struct StartEmailEnrollmentRequest {
    let token: String
    let domain: String
    let email: String
}


struct StartEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    
    func execute(request: StartEmailEnrollmentRequest)  async throws -> EmailEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain)
            .authenticationMethods
            .enrollEmail(emailAddress: request.email)
            .start()
    }
}
