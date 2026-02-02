import Auth0
import Foundation

/// Request model for fetching authentication methods.
///
/// Contains the authentication token and Auth0 domain required to retrieve
/// the user's enrolled authentication methods.
struct GetAuthMethodsRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
}

/// Protocol for the authentication methods retrieval use case.
protocol GetAuthMethodsUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Fetches all enrolled authentication methods for the current user.
    ///
    /// - Parameter request: The request containing token and domain
    /// - Returns: An array of enrolled authentication methods
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: GetAuthMethodsRequest) async throws -> [AuthenticationMethod]
}

/// Use case for retrieving authentication methods.
///
/// Fetches all authentication methods (email, SMS, TOTP, push, passkeys, recovery codes)
/// that are currently enrolled for the user's account from Auth0's My Account API.
struct GetAuthMethodsUseCase: GetAuthMethodsUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    /// Fetches all authentication methods for the current user.
    ///
    /// - Parameter request: Request containing authentication token and domain
    /// - Returns: Array of enrolled authentication methods
    /// - Throws: Auth0APIError if the request fails
    func execute(request: GetAuthMethodsRequest) async throws -> [AuthenticationMethod] {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .getAuthenticationMethods()
            .start()
    }
}
