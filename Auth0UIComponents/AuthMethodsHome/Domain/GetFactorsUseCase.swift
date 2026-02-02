import Foundation
import Auth0

/// Request parameters for retrieving factors.
struct GetFactorsRequest {
    let token: String
    let domain: String
}

/// Protocol for retrieving factors.
protocol GetFactorsUseCaseable {
    var session: URLSession { get }
    func execute(request: GetFactorsRequest) async throws -> [Factor]
}

/// Use case for retrieving the list of factors.
struct GetFactorsUseCase: GetFactorsUseCaseable {
    var session: URLSession

    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    func execute(request: GetFactorsRequest) async throws -> [Factor] {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .getFactors()
            .start()
    }
}
