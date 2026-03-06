import Auth0
import Combine

/// Protocol for managing authentication credentials and tokens.
///
/// This protocol defines the interface for credential management operations used by Auth0 UI Components.
/// Implementers are responsible for fetching, storing, and managing user credentials and API tokens.
/// Must conform to Sendable for use in async/await contexts and thread-safe operations.
///
/// Example:
/// ```swift
/// class MyTokenProvider: TokenProvider {
///     private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
///     private var apiCredentialsCache: [String: APICredentials] = [:]
///
///     func fetchCredentials() async throws -> Credentials {
///         guard let credentials = try credentialsManager.credentials() else {
///             throw NSError(domain: "TokenProvider", code: -1, userInfo: nil)
///         }
///         return credentials
///     }
///
///     func storeCredentials(credentials: Credentials) {
///         try? credentialsManager.store(credentials: credentials)
///     }
///
///     func store(apiCredentials: APICredentials, for audience: String) {
///         apiCredentialsCache[audience] = apiCredentials
///     }
///
///     func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
///         if let cached = apiCredentialsCache[audience] {
///             return cached
///         }
///         // Fetch new API credentials
///         let credentials = try await Auth0.authentication()
///             .credentials(forAudience: audience, scope: scope)
///         store(apiCredentials: credentials, for: audience)
///         return credentials
///     }
/// }
/// ```
///
/// Dependencies: Requires Auth0 SDK framework
public protocol TokenProvider: Sendable {
    /// Fetches the current user credentials from storage.
    ///
    /// - Returns: The user's stored credentials
    /// - Throws: An error if credentials cannot be retrieved or are invalid
    func fetchCredentials() async throws -> Credentials

    /// Stores user credentials for later retrieval.
    ///
    /// - Parameter credentials: The credentials to store
    func storeCredentials(credentials: Credentials)

    /// Stores API credentials for a specific audience and scope.
    ///
    /// - Parameters:
    ///   - apiCredentials: The API credentials to store
    ///   - audience: The API audience (e.g., "https://api.example.com")
    func store(apiCredentials: APICredentials, for audience: String)

    /// Fetches API credentials for a specific audience and scope.
    ///
    /// - Parameters:
    ///   - audience: The API audience (e.g., "https://api.example.com")
    ///   - scope: The requested scopes (space-separated)
    /// - Returns: API credentials for the requested audience and scope
    /// - Throws: An error if credentials cannot be fetched or refreshed
    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials
}

extension TokenProvider {
    /// Default implementation of fetchAPICredentials that calls the protocol method.
    ///
    /// - Parameters:
    ///   - audience: The API audience (e.g., "https://api.example.com")
    ///   - scope: The requested scopes (space-separated)
    /// - Returns: API credentials for the requested audience and scope
    /// - Throws: An error if credentials cannot be fetched or refreshed
    func fetchAPICredentials(audience: String, scope: String) async throws -> APICredentials {
        try await self.fetchAPICredentials(audience: audience, scope: scope)
    }
}
