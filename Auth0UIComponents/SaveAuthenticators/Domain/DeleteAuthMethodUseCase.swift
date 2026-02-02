import Auth0
import Foundation
import Combine

/// Protocol for deleting an authentication method.
protocol DeleteAuthMethodUseCaseable {
    var session: URLSession  { get }
    func execute(request: DeleteAuthMethodRequest) async throws
}

/// Request parameters for deleting an authentication method.
struct DeleteAuthMethodRequest {
    let token: String
    let domain: String
    let id: String
}

/// Use case for deleting an authentication method.
struct DeleteAuthMethodUseCase: DeleteAuthMethodUseCaseable {
    var session: URLSession = .shared
    
    func execute(request: DeleteAuthMethodRequest) async throws {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .deleteAuthenticationMethod(by: request.id)
            .start()
    }
}
