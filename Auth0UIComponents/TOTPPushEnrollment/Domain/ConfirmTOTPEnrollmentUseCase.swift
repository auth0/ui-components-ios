import Auth0
import Foundation

struct ConfirmTOTPEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
    let otpCode: String
}

protocol ConfirmTOTPEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: ConfirmTOTPEnrollmentRequest) async throws -> AuthenticationMethod
}

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
