import Auth0
import Foundation

/// Request model for initiating push notification enrollment
struct StartPushEnrollmentRequest {
    let token: String
    let domain: String
}

/// Protocol for push notification enrollment use case
protocol StartPushEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: StartPushEnrollmentRequest) async throws -> PushEnrollmentChallenge
}

/// Use case to initiate push notification enrollment
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
