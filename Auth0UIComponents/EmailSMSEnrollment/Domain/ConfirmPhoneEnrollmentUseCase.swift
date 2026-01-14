import Auth0
import Foundation
import Combine

protocol ConfirmPhoneEnrollmentUseCaseable {
    var session: URLSession { get }
    
    func execute(request: ConfirmPhoneEnrollmentRequest) async throws -> AuthenticationMethod
}

struct ConfirmPhoneEnrollmentRequest {
    let token: String
    let domain: String
    let id: String
    let authSession: String
    let otpCode: String
}

struct ConfirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCaseable {
    var session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func execute(request: ConfirmPhoneEnrollmentRequest) async throws -> AuthenticationMethod {
        do {
            let authenticationMethod = try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
                .authenticationMethods
                .confirmPhoneEnrollment(id: request.id, authSession: request.authSession, otpCode: request.otpCode)
                .start()
            refreshAuthComponents.send(())
            return authenticationMethod
        } catch {
            throw error
        }
    }
}
