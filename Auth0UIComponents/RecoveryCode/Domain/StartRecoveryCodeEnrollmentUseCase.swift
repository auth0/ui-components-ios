import Auth0
import Foundation

protocol StartRecoveryCodeEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartRecoveryCodeEnrollmentRequest) async throws  -> RecoveryCodeEnrollmentChallenge
}

struct StartRecoveryCodeEnrollmentRequest {
    let token: String
    let domain: String
}

struct StartRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(request: StartRecoveryCodeEnrollmentRequest) async throws  -> RecoveryCodeEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollRecoveryCode()
            .start()
    }
}
