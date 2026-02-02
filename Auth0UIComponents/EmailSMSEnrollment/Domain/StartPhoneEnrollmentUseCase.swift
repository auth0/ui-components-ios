import Auth0
import Foundation

/// Request model for initiating phone enrollment.
///
/// Contains the authentication token, Auth0 domain, phone number, and preferred
/// authentication method (SMS or voice call).
struct StartPhoneEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// The phone number to enroll for authentication
    let phoneNumber: String
    /// The preferred method to receive codes (SMS by default, or voice call)
    let preferredAuthenticationMethod: PreferredAuthenticationMethod = .sms
}

/// Protocol for the phone enrollment initiation use case.
protocol StartPhoneEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Initiates phone enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: The request containing token, domain, and phone number
    /// - Returns: A PhoneEnrollmentChallenge for verification
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: StartPhoneEnrollmentRequest) async throws -> PhoneEnrollmentChallenge
}

/// Use case for starting phone authentication method enrollment.
///
/// Initiates phone enrollment by requesting a verification challenge from
/// Auth0's My Account API. The user will receive an SMS or voice call at the
/// provided phone number to complete the enrollment.
struct StartPhoneEnrollmentUseCase: StartPhoneEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Starts phone enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: Request containing authentication token, domain, and phone number
    /// - Returns: Phone enrollment challenge with verification details
    /// - Throws: Auth0APIError if the request fails
    func execute(request: StartPhoneEnrollmentRequest) async throws -> PhoneEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollPhone(phoneNumber: request.phoneNumber, preferredAuthenticationMethod: request.preferredAuthenticationMethod)
            .start()
    }
}
