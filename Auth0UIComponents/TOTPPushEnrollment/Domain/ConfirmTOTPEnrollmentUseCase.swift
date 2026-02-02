import Auth0
import Foundation
import Combine

/// Request model for confirming TOTP enrollment with OTP code
struct ConfirmTOTPEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
    let otpCode: String
}

/// Protocol for confirming TOTP enrollment
protocol ConfirmTOTPEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: ConfirmTOTPEnrollmentRequest) async throws -> AuthenticationMethod
}

/// Use case to confirm TOTP enrollment with verification code
struct ConfirmTOTPEnrollmentUseCase: ConfirmTOTPEnrollmentUseCaseable {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(request: ConfirmTOTPEnrollmentRequest) async throws -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmTOTPEnrollment(id: request.id, authSession: request.authSession, otpCode: request.otpCode)
            .start()
    }
}
