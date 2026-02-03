import Foundation
import Auth0

/// Request model for fetching authentication factors.
///
/// Contains the authentication token and Auth0 domain required to retrieve
/// the available authentication factors for the user's account.
struct GetFactorsRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
}

/// Protocol for the authentication factors retrieval use case.
protocol GetFactorsUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Fetches all available authentication factors for the current user.
    ///
    /// - Parameter request: The request containing token and domain
    /// - Returns: An array of available authentication factors
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: GetFactorsRequest) async throws -> [Factor]
}

/// Use case for retrieving authentication factors.
///
/// Fetches the list of available authentication factors that can be used
/// for additional authentication or recovery from the user's account.
struct GetFactorsUseCase: GetFactorsUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    /// Fetches all authentication factors for the current user.
    ///
    /// - Parameter request: Request containing authentication token and domain
    /// - Returns: Array of available authentication factors
    /// - Throws: Auth0APIError if the request fails
    func execute(request: GetFactorsRequest) async throws -> [Factor] {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .getFactors()
            .start()
    }
}
