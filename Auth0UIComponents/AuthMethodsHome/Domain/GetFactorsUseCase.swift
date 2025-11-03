import Auth0
import Foundation

/// A structured request object containing the credentials required to fetch a user's enrolled
/// multi-factor authentication (MFA) factors.
///
/// This structure decouples the execution logic from the data needed to perform the request,
/// making the use case easier to test and manage.
struct GetFactorsRequest {
    /// The **access token** required to authorize the request to the MyAccount endpoint.
    let token: String
    /// The **domain** of the Auth0 tenant (e.g., "my-tenant.auth0.com").
    let domain: String
}

/// Defines the contract for a use case responsible for fetching a user's configured MFA factors.
///
/// Implementations of this protocol are responsible for securely communicating with the
/// Auth0 MyAccount API to retrieve the list of enrolled authentication factors.
protocol GetFactorsUseCaseable {
    /// The URLSession instance used for network requests.
    var session: URLSession { get }
    
    /// Executes the network request to retrieve the multi-factor authentication factors for the user.
    ///
    /// - Parameter request: The ``GetFactorsRequest`` containing the token and domain.
    /// - Returns: An array of ``Factor`` objects representing the user's enrolled MFA factors.
    /// - Throws: An error if the network request fails, the token is invalid, or decoding the response fails.
    func execute(request: GetFactorsRequest) async throws -> [Factor]
}

/// Concrete implementation of the ``GetFactorsUseCaseable`` protocol.
///
/// This use case leverages the `Auth0.swift` SDK's MyAccount feature to securely retrieve
/// the list of enrolled authentication factors.
struct GetFactorsUseCase: GetFactorsUseCaseable {
    /// The URLSession instance used for network requests.
    var session: URLSession

    /// Initializes the use case with an optional custom `URLSession`.
    /// - Parameter session: The session to use for API calls. Defaults to `URLSession.shared`.
    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    /// Executes the network request to retrieve the multi-factor authentication factors for the user.
    ///
    /// This method constructs the necessary Auth0 API call using the access token and starts the asynchronous operation.
    ///
    /// - Parameter request: The ``GetFactorsRequest`` containing the access token and domain.
    /// - Returns: An array of ``Factor`` objects.
    /// - Throws: An error propagated from the Auth0 SDK call, such as network failures or authorization errors.
    func execute(request: GetFactorsRequest) async throws -> [Factor] {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .getFactors()
            .start()
    }
}
