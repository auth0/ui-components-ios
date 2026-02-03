import Auth0
import Foundation
import Combine

/// Protocol for the email enrollment confirmation use case.
protocol ConfirmEmailEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Confirms email enrollment with the OTP code.
    ///
    /// - Parameter request: The request containing enrollment details and OTP code
    /// - Returns: The created authentication method
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: ConfirmEmailEnrollmentRequest) async throws -> AuthenticationMethod
}

/// Request model for confirming email enrollment.
///
/// Contains all the necessary information to verify the email enrollment
/// by providing the one-time password sent to the user's email.
///
/// ## See Also
///
/// - [Email MFA](https://auth0.com/docs/secure/multi-factor-authentication/multi-factor-authentication-factors#email)
/// - [My Account API](https://auth0.com/docs/manage-users/my-account-api)
struct ConfirmEmailEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// The enrollment ID from the initial challenge. This uniquely identifies the authentication
    /// method being enrolled.
    let id: String
    /// The authentication session identifier from the challenge. Used to maintain session state
    /// during the enrollment flow.
    let authSession: String
    /// The OTP code from the email verification message. This is the one-time code sent to
    /// the user's email address to verify ownership.
    let otpCode: String
}

/// Use case for confirming email authentication method enrollment.
///
/// Verifies the email enrollment by validating the one-time password that was
/// sent to the user's email address. Upon successful verification, the email
/// authentication method is enrolled for the user's account.
struct ConfirmEmailEnrollmentUseCase: ConfirmEmailEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Confirms email enrollment with the provided OTP code.
    ///
    /// - Parameter request: Request containing enrollment details and OTP code
    /// - Returns: The newly created email authentication method
    /// - Throws: Auth0APIError if the OTP is invalid or the request fails
    func execute(request: ConfirmEmailEnrollmentRequest) async throws -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmEmailEnrollment(id: request.id, authSession: request.authSession, otpCode: request.otpCode)
            .start()
    }
}
