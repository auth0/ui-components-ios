import Auth0
import Foundation

/// Request model for initiating TOTP enrollment
struct StartTOTPEnrollmentRequest {
    let token: String
    let domain: String
}

/// Protocol for TOTP enrollment use case
protocol StartTOTPEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartTOTPEnrollmentRequest) async throws -> TOTPEnrollmentChallenge
}

/// Use case to initiate TOTP enrollment
struct StartTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCaseable {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(request: StartTOTPEnrollmentRequest) async throws -> TOTPEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollTOTP()
            .start()
    }
}
