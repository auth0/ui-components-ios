import Auth0

extension CredentialsManager: TokenProvider {

    public func fetchCredentials() async throws -> Credentials {
        try await credentials()
    }

    public func storeCredentials(credentials: Credentials) {
        _ = store(credentials: credentials)
    }

    public func store(apiCredentials: APICredentials, for audience: String) {
        _ = store(apiCredentials: apiCredentials, forAudience: audience)
    }

    public func fetchAPICredentials(audience: String, scope: String, headers: [String: String]) async throws -> APICredentials {
        try await apiCredentials(forAudience: audience, scope: scope, headers: headers)
    }
}
