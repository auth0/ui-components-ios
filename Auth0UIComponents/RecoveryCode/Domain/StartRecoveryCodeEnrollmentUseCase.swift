import Auth0
import Foundation

/// Protocol for the recovery code enrollment initiation use case.
protocol StartRecoveryCodeEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Initiates recovery code enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: The request containing token and domain
    /// - Returns: A RecoveryCodeEnrollmentChallenge with the recovery codes
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: StartRecoveryCodeEnrollmentRequest) async throws -> RecoveryCodeEnrollmentChallenge
}

/// Request model for initiating recovery code enrollment.
///
/// Contains the authentication token and Auth0 domain required to generate
/// recovery codes for account recovery.
struct StartRecoveryCodeEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
}

/// Use case for starting recovery code enrollment.
///
/// Initiates recovery code generation by requesting a challenge from Auth0's
/// My Account API. Recovery codes are backup codes that can be used to access
/// the account if other authentication methods are not available.
struct StartRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Starts recovery code enrollment and returns the recovery codes.
    ///
    /// - Parameter request: Request containing authentication token and domain
    /// - Returns: Recovery code enrollment challenge with generated codes
    /// - Throws: Auth0APIError if the request fails
    func execute(request: StartRecoveryCodeEnrollmentRequest) async throws -> RecoveryCodeEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollRecoveryCode()
            .start()
    }
}
