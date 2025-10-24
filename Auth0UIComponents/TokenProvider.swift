import Auth0
import Combine

public protocol TokenProvider {
    func fetchCredentials() async throws -> Credentials
    func fetchCredentials() -> AnyPublisher<Credentials, CredentialsManagerError>
    func storeCredentials(credentials: Credentials)
    func store(apiCredentials: APICredentials, for audience: String)
    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials
    func fetchAPICredentials(audience: String, scope: String) -> AnyPublisher<APICredentials, CredentialsManagerError>
}

extension CredentialsManager: TokenProvider {

    public func fetchCredentials() async throws -> Credentials {
        try await credentials()
    }

    public func fetchCredentials() -> AnyPublisher<Credentials, CredentialsManagerError> {
        credentials()
    }

    public func storeCredentials(credentials: Credentials) {
        _ = store(credentials: credentials)
    }
    
    public func store(apiCredentials: APICredentials, for audience: String) {
        _ = store(apiCredentials: apiCredentials, forAudience: audience)
    }

    public func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        try await apiCredentials(forAudience: audience, scope: scope)
    }

    public func fetchAPICredentials(audience: String, scope: String) -> AnyPublisher<APICredentials, CredentialsManagerError> {
        apiCredentials(forAudience: audience, scope: scope)
    }
}
