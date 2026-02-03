import Auth0
import Foundation
import Combine

/// Protocol for the authentication method deletion use case.
protocol DeleteAuthMethodUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Deletes an authentication method.
    ///
    /// - Parameter request: The request containing the method ID to delete
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: DeleteAuthMethodRequest) async throws
}

/// Request model for deleting an authentication method.
///
/// Contains the authentication token, Auth0 domain, and the ID of the
/// authentication method to delete.
///
/// ## See Also
///
/// - [My Account API](https://auth0.com/docs/manage-users/my-account-api)
struct DeleteAuthMethodRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// The ID of the authentication method to delete. This is the unique identifier
    /// of the enrolled authenticator (e.g., "totp|abc123", "sms|xyz789").
    let id: String
}

/// Use case for deleting authentication methods.
///
/// Removes an enrolled authentication method from the user's account.
/// This allows users to delete unwanted authenticators they no longer need.
struct DeleteAuthMethodUseCase: DeleteAuthMethodUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession = .shared

    /// Deletes an authentication method from the user's account.
    ///
    /// - Parameter request: Request containing the method ID to delete
    /// - Throws: Auth0APIError if the method cannot be deleted
    func execute(request: DeleteAuthMethodRequest) async throws {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .deleteAuthenticationMethod(by: request.id)
            .start()
    }
}
