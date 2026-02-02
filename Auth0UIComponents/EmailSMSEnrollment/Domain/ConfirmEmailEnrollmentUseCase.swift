import Auth0
import Foundation
import Combine

/// Protocol for confirming email enrollment with an OTP code.
protocol ConfirmEmailEnrollmentUseCaseable {
    var session: URLSession { get }
    
    func execute(request: ConfirmEmailEnrollmentRequest) async throws -> AuthenticationMethod
}

/// Request parameters for confirming email enrollment.
struct ConfirmEmailEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
    let otpCode: String
}

/// Use case for confirming email enrollment via OTP verification.
struct ConfirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(request: ConfirmEmailEnrollmentRequest) async throws  -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmEmailEnrollment(id: request.id, authSession: request.authSession, otpCode: request.otpCode)
            .start()
    }
}
