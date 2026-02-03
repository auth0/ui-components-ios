import Auth0
import Foundation
import Combine

/// Protocol for the phone enrollment confirmation use case.
protocol ConfirmPhoneEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Confirms phone enrollment with the OTP code.
    ///
    /// - Parameter request: The request containing enrollment details and OTP code
    /// - Returns: The created authentication method
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: ConfirmPhoneEnrollmentRequest) async throws -> AuthenticationMethod
}

/// Request model for confirming phone enrollment.
///
/// Contains all the necessary information to verify the phone enrollment
/// by providing the one-time password sent via SMS or received via voice call.
///
/// ## See Also
///
/// - [SMS MFA](https://auth0.com/docs/secure/multi-factor-authentication/multi-factor-authentication-factors#sms)
/// - [My Account API](https://auth0.com/docs/manage-users/my-account-api)
struct ConfirmPhoneEnrollmentRequest {
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
    /// The OTP code from the SMS or voice call. This is the one-time code sent to
    /// the user's phone number to verify ownership.
    let otpCode: String
}

/// Use case for confirming phone authentication method enrollment.
///
/// Verifies the phone enrollment by validating the one-time password that was
/// sent to the user's phone via SMS or voice call. Upon successful verification,
/// the phone authentication method is enrolled for the user's account.
struct ConfirmPhoneEnrollmentUseCase: ConfirmPhoneEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Confirms phone enrollment with the provided OTP code.
    ///
    /// - Parameter request: Request containing enrollment details and OTP code
    /// - Returns: The newly created phone authentication method
    /// - Throws: Auth0APIError if the OTP is invalid or the request fails
    func execute(request: ConfirmPhoneEnrollmentRequest) async throws -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmPhoneEnrollment(id: request.id, authSession: request.authSession, otpCode: request.otpCode)
            .start()
    }
}
