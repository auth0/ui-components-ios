import Auth0
import Foundation
import Combine

/// Protocol for confirming phone enrollment with an OTP code.
protocol ConfirmPhoneEnrollmentUseCaseable {
    var session: URLSession { get }
    
    func execute(request: ConfirmPhoneEnrollmentRequest) async throws -> AuthenticationMethod
}

/// Request parameters for confirming phone enrollment.
struct ConfirmPhoneEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
    let otpCode: String
}

/// Use case for confirming phone enrollment via OTP verification.
struct ConfirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(request: ConfirmPhoneEnrollmentRequest) async throws -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmPhoneEnrollment(id: request.id, authSession: request.authSession, otpCode: request.otpCode)
            .start()
    }
}
