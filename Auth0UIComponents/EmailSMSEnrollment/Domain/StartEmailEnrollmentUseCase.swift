import Auth0
import Foundation

/// Protocol for the email enrollment initiation use case.
protocol StartEmailEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Initiates email enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: The request containing token, domain and email
    /// - Returns: An EmailEnrollmentChallenge for verification
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: StartEmailEnrollmentRequest) async throws -> EmailEnrollmentChallenge
}

/// Request model for initiating email enrollment.
///
/// Contains the authentication token, Auth0 domain, and email address
/// to be enrolled as an authentication method.
///
/// ## See Also
///
/// - [Email MFA](https://auth0.com/docs/secure/multi-factor-authentication/multi-factor-authentication-factors#email)
struct StartEmailEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// The email address to enroll for authentication. The user will receive a verification code
    /// at this email address to complete enrollment.
    let email: String
}

/// Use case for starting email authentication method enrollment.
///
/// Initiates email enrollment by requesting a verification challenge from
/// Auth0's My Account API. The user will receive a verification link or code
/// at the provided email address to complete the enrollment.
struct StartEmailEnrollmentUseCase: StartEmailEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Starts email enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: Request containing authentication token, domain, and email
    /// - Returns: Email enrollment challenge with verification details
    /// - Throws: Auth0APIError if the request fails
    func execute(request: StartEmailEnrollmentRequest) async throws -> EmailEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollEmail(emailAddress: request.email)
            .start()
    }
}
