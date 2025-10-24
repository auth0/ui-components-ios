import Auth0
import Foundation

protocol ConfirmEmailEnrollmentUseCaseable {
    var session: URLSession { get }
    
    func execute(request: ConfirmEmailEnrollmentRequest) async throws -> AuthenticationMethod
}

struct ConfirmEmailEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
    let otpCode: String
}


struct ConfirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(request: ConfirmEmailEnrollmentRequest) async throws  -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain)
            .authenticationMethods
            .confirmEmailEnrollment(id: request.id, authSession: request.authSession, otpCode: request.otpCode)
            .start()
    }
}
