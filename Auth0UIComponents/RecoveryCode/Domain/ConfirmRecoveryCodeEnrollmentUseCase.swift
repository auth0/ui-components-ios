import Auth0
import Foundation
import Combine

/// Protocol for confirming recovery code enrollment.
protocol ConfirmRecoveryCodeEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: ConfirmRecoveryCodeEnrollmentRequest) async throws  -> AuthenticationMethod
}

/// Request parameters for confirming recovery code enrollment.
struct ConfirmRecoveryCodeEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
}

/// Use case for confirming recovery code enrollment.
struct ConfirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(request: ConfirmRecoveryCodeEnrollmentRequest) async throws  -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmRecoveryCodeEnrollment(id: request.id, authSession: request.authSession)
            .start()
    }
}

