import Auth0
import Foundation
import Combine

/// Protocol for the recovery code enrollment confirmation use case.
protocol ConfirmRecoveryCodeEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Confirms recovery code enrollment.
    ///
    /// - Parameter request: The request containing enrollment details
    /// - Returns: The created authentication method
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: ConfirmRecoveryCodeEnrollmentRequest) async throws -> AuthenticationMethod
}

/// Request model for confirming recovery code enrollment.
///
/// Contains the enrollment session information needed to complete
/// the recovery code enrollment process.
struct ConfirmRecoveryCodeEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// The enrollment ID from the initial challenge
    let id: String
    /// The authentication session identifier from the challenge
    let authSession: String
}

/// Use case for confirming recovery code enrollment.
///
/// Completes the recovery code enrollment process by confirming the
/// enrollment session. Upon successful confirmation, the recovery codes
/// can be used to access the account if other authentication methods fail.
struct ConfirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Confirms recovery code enrollment.
    ///
    /// - Parameter request: Request containing enrollment details
    /// - Returns: The newly created recovery code authentication method
    /// - Throws: Auth0APIError if the request fails
    func execute(request: ConfirmRecoveryCodeEnrollmentRequest) async throws -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmRecoveryCodeEnrollment(id: request.id, authSession: request.authSession)
            .start()
    }
}
