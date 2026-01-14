import Auth0
import Foundation


struct GetAuthMethodsRequest {
  
    let token: String

    let domain: String
}

protocol GetAuthMethodsUseCaseable {
    var session: URLSession { get }
    func execute(request: GetAuthMethodsRequest) async throws -> [AuthenticationMethod]
}

struct GetAuthMethodsUseCase: GetAuthMethodsUseCaseable {
    var session: URLSession

    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    func execute(request: GetAuthMethodsRequest) async throws -> [AuthenticationMethod] {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .getAuthenticationMethods()
            .start()
    }
}
