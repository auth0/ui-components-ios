import Auth0
import Foundation
import Combine

protocol DeleteAuthMethodUseCaseable {
    var session: URLSession  { get }
    func execute(request: DeleteAuthMethodRequest) async throws
}

struct DeleteAuthMethodRequest {
    let token: String
    let domain: String
    let id: String
}

struct DeleteAuthMethodUseCase: DeleteAuthMethodUseCaseable {
    var session: URLSession = .shared
    
    func execute(request: DeleteAuthMethodRequest) async throws {
        do {
            try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
                .authenticationMethods
                .deleteAuthenticationMethod(by: request.id)
                .start()
                refreshAuthComponents.send(())
        } catch {
            throw error
        }
    }
}
