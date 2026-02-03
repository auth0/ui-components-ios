import Auth0
import Foundation

/// Request model for initiating TOTP enrollment.
///
/// Contains the authentication token and Auth0 domain required to start
/// the TOTP enrollment process.
struct StartTOTPEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
}

/// Protocol for the TOTP enrollment initiation use case.
protocol StartTOTPEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Initiates TOTP enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: The request containing token and domain
    /// - Returns: A TOTPEnrollmentChallenge containing QR code and secret
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: StartTOTPEnrollmentRequest) async throws -> TOTPEnrollmentChallenge
}

/// Use case for starting TOTP (Time-based One-Time Password) enrollment.
///
/// Initiates the TOTP enrollment process by requesting a challenge from
/// Auth0's My Account API. Returns a QR code and secret for the user to
/// configure their authenticator app.
struct StartTOTPEnrollmentUseCase: StartTOTPEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Starts TOTP enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: Request containing authentication token and domain
    /// - Returns: TOTP enrollment challenge with QR code and secret
    /// - Throws: Auth0APIError if the request fails
    func execute(request: StartTOTPEnrollmentRequest) async throws -> TOTPEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollTOTP()
            .start()
    }
}
