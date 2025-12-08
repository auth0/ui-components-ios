import Auth0
import Combine

/// A mechanism for securely fetching and storing two distinct types of authentication tokens:
/// general user credentials and audience-specific API credentials.
///
/// The ``TokenProvider`` is designed to abstract the underlying storage technology (e.g., Keychain, disk)
/// from the rest of the application's authentication flow. It handles the lifecycle for fetching,
/// validating, and persisting tokens required for user sessions and API access.
public protocol TokenProvider {

    // MARK: - General Credentials (e.g., Refresh/Access Token Pair)
    
    /// Asynchronously retrieves the currently stored primary user credentials.
    ///
    /// This method is typically used to retrieve tokens necessary for maintaining a user session,
    /// such as an access token and a refresh token. Implementations must handle secure
    /// retrieval from storage and token validation if necessary.
    ///
    /// - Returns: The currently stored `Credentials` object.
    /// - Throws: A `CredentialError` or similar error if the credentials cannot be
    ///   found, are invalid, or if the underlying secure storage operation fails.
    func fetchCredentials() async throws -> Credentials
    
    /// Stores the provided primary user credentials securely.
    ///
    /// This is typically called after a successful login or a token refresh operation.
    /// This method is synchronous as it primarily involves writing to a local storage mechanism.
    ///
    /// - Parameter credentials: The `Credentials` object containing user tokens to be persisted securely.
    func storeCredentials(credentials: Credentials)
    
    // MARK: - API Credentials (e.g., Tokens for External APIs)
    
    /// Stores audience-specific API credentials securely.
    ///
    /// API credentials (like machine-to-machine tokens) are often tied to a specific
    /// resource or service identified by its audience string.
    ///
    /// - Parameters:
    ///   - apiCredentials: The `APICredentials` object to be stored.
    ///   - audience: The unique URI or identifier for the target API. This acts as the key for storage.
    func store(apiCredentials: APICredentials, for audience: String)
    
    /// Asynchronously retrieves audience-specific API credentials, optionally requiring a specific scope.
    ///
    /// This method is used when the application needs to make a secure request to a service
    /// whose credentials are managed separately from the main user session.
    ///
    /// - Parameters:
    ///   - audience: The unique URI or identifier for the target API whose credentials are being requested.
    ///   - scope: The required scope(s) for the credentials. The implementation should ensure
    ///     the returned credentials satisfy this requirement.
    /// - Returns: The stored and validated `APICredentials` object for the specified **audience**.
    /// - Throws: An error if the credentials cannot be found, have expired and cannot be refreshed,
    ///   or do not contain the necessary **scope**.
    ///   
    func fetchAPICredentials(audience: String, scope: String, headers: [String: String]) async throws -> APICredentials
}

extension TokenProvider {
    func fetchAPICredentials(audience: String, scope: String, headers: [String: String] = [:]) async throws -> APICredentials {
        try await self.fetchAPICredentials(audience: audience, scope: scope, headers: headers)
    }
}
