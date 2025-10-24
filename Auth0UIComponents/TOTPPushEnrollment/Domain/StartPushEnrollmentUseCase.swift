import Auth0
import Foundation

struct StartPushEnrollmentRequest {
    let token: String
    let domain: String
}

protocol StartPushEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartPushEnrollmentRequest) async throws -> PushEnrollmentChallenge
}

struct StartPushEnrollmentUseCase: StartPushEnrollmentUseCaseable {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(request: StartPushEnrollmentRequest) async throws -> PushEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollPushNotification()
            .start()
    }
}
