import Auth0
import Foundation

struct StartTOTPEnrollmentRequest {
    let token: String
    let domain: String
}

protocol StartTOTPEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartTOTPEnrollmentRequest) async throws -> TOTPEnrollmentChallenge
}

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
