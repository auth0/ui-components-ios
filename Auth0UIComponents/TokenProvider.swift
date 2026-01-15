import Auth0
import Combine

public protocol TokenProvider: Sendable {
    func fetchCredentials() async throws -> Credentials
 
    func storeCredentials(credentials: Credentials)

    func store(apiCredentials: APICredentials, for audience: String)

    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials
}

extension TokenProvider {
    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        try await self.fetchAPICredentials(audience: audience, scope: scope)
    }
}
