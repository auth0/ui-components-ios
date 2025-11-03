import Auth0
import Foundation

/// A structured request object containing all necessary parameters to fetch authentication methods.
///
/// This structure decouples the execution logic from the data needed to perform the request,
/// making the use case easier to test and manage.
struct GetAuthMethodsRequest {
    /// The access token required to authorize the request to the MyAccount endpoint.
    let token: String
    /// The domain of the Auth0 tenant (e.g., "my-tenant.auth0.com").
    let domain: String
}

/// Defines the contract for fetching a user's configured authentication methods.
///
/// Implementations of this protocol are responsible for making the network request
/// to the appropriate Auth0 endpoint and handling the response decoding.
protocol GetAuthMethodsUseCaseable {
    /// The URLSession instance used for network requests.
    var session: URLSession { get }

    /// Executes the network request to retrieve the authentication methods for the user.
    ///
    /// - Parameter request: The ``GetAuthMethodsRequest`` containing the token and domain.
    /// - Returns: An array of ``AuthenticationMethod`` objects configured for the user.
    /// - Throws: An error if the network request fails, the token is invalid, or decoding the response fails.
    func execute(request: GetAuthMethodsRequest) async throws -> [AuthenticationMethod]
}

/// Concrete implementation of the ``GetAuthMethodsUseCaseable`` protocol.
///
/// This use case leverages the `Auth0.swift` SDK to securely retrieve authentication methods
/// from the MyAccount API.
struct GetAuthMethodsUseCase: GetAuthMethodsUseCaseable {
    /// The URLSession instance used for network requests.
    var session: URLSession

    /// Initializes the use case with an optional custom `URLSession`.
    /// - Parameter session: The session to use for API calls. Defaults to `URLSession.shared`.
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    /// Executes the network request to retrieve the authentication methods for the user.
    ///
    /// This method constructs the necessary Auth0 API call and starts the asynchronous operation.
    ///
    /// - Parameter request: The ``GetAuthMethodsRequest`` containing the access token and domain.
    /// - Returns: An array of ``AuthenticationMethod`` objects.
    /// - Throws: An error propagated from the Auth0 SDK call, such as network failures or authorization errors.
    func execute(request: GetAuthMethodsRequest) async throws -> [AuthenticationMethod] {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .getAuthenticationMethods()
            .start()
    }
}
