import Auth0
import Foundation
import Combine

protocol ConfirmRecoveryCodeEnrollmentUseCaseable {
    var session: URLSession { get }
    func execute(request: ConfirmRecoveryCodeEnrollmentRequest) async throws  -> AuthenticationMethod
}

struct ConfirmRecoveryCodeEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
}

struct ConfirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(request: ConfirmRecoveryCodeEnrollmentRequest) async throws  -> AuthenticationMethod {
        do {
            let authenticationMethod = try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
                .authenticationMethods
                .confirmRecoveryCodeEnrollment(id: request.id, authSession: request.authSession)
                .start()
            return authenticationMethod
        } catch {
            throw error
        }
    }
}

