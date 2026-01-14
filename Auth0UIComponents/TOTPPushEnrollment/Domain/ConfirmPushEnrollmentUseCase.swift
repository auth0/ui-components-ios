import Auth0
import Foundation
import Combine

struct ConfirmPushEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
}


protocol ConfirmPushEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: ConfirmPushEnrollmentRequest) async throws -> AuthenticationMethod
}

struct ConfirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(request: ConfirmPushEnrollmentRequest) async throws -> AuthenticationMethod {
        do {
            let authenticationMethod = try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
                .authenticationMethods
                .confirmPushNotificationEnrollment(id: request.id, authSession: request.authSession)
                .start()
            refreshAuthComponents.send(())
            return authenticationMethod
        } catch {
            throw error
        }
    }
}
