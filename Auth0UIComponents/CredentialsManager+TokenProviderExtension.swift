import Auth0

/// Extension making Auth0's CredentialsManager conform to the TokenProvider protocol.
///
/// This extension bridges Auth0 SDK's CredentialsManager with Auth0 UI Components'
/// TokenProvider protocol, allowing the native Auth0 credentials management to be used
/// directly with Auth0 UI Components.
extension CredentialsManager: TokenProvider {

    /// Fetches the current user credentials from the credentials manager.
    ///
    /// - Returns: The user's stored credentials
    /// - Throws: CredentialsManagerError if credentials cannot be retrieved
    public func fetchCredentials() async throws -> Credentials {
        try await credentials()
    }

    /// Stores user credentials in the credentials manager.
    ///
    /// - Parameter credentials: The credentials to store
    public func storeCredentials(credentials: Credentials) {
        _ = store(credentials: credentials)
    }

    /// Stores API credentials for a specific audience in the credentials manager.
    ///
    /// - Parameters:
    ///   - apiCredentials: The API credentials to store
    ///   - audience: The API audience (e.g., "https://api.example.com")
    public func store(apiCredentials: APICredentials, for audience: String) {
        _ = store(apiCredentials: apiCredentials, forAudience: audience)
    }

    /// Fetches API credentials for a specific audience and scope from the credentials manager.
    ///
    /// - Parameters:
    ///   - audience: The API audience (e.g., "https://api.example.com")
    ///   - scope: The requested scopes (space-separated)
    /// - Returns: API credentials for the requested audience and scope
    /// - Throws: CredentialsManagerError if credentials cannot be fetched or refreshed
    public func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        try await apiCredentials(forAudience: audience, scope: scope)
    }
}
