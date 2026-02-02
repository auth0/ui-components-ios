import Auth0
import Foundation
import Combine

/// Request model for confirming push notification enrollment
struct ConfirmPushEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
}

/// Protocol for confirming push notification enrollment
protocol ConfirmPushEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: ConfirmPushEnrollmentRequest) async throws -> AuthenticationMethod
}

/// Use case to confirm push notification enrollment
struct ConfirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCaseable {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(request: ConfirmPushEnrollmentRequest) async throws -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmPushNotificationEnrollment(id: request.id, authSession: request.authSession)
            .start()
    }
}
