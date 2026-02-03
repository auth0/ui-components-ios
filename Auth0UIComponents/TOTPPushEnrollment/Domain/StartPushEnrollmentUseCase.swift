import Auth0
import Foundation

/// Request model for initiating push notification enrollment.
///
/// Contains the authentication token and Auth0 domain required to start
/// the push notification enrollment process.
struct StartPushEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
}

/// Protocol for the push notification enrollment initiation use case.
protocol StartPushEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Initiates push notification enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: The request containing token and domain
    /// - Returns: A PushEnrollmentChallenge with enrollment details
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: StartPushEnrollmentRequest) async throws -> PushEnrollmentChallenge
}

/// Use case for starting push notification authentication enrollment.
///
/// Initiates the push notification enrollment process by requesting a challenge
/// from Auth0's My Account API. This prepares the account for push notification-based
/// authentication when signing in.
struct StartPushEnrollmentUseCase: StartPushEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Starts push notification enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: Request containing authentication token and domain
    /// - Returns: Push notification enrollment challenge
    /// - Throws: Auth0APIError if the request fails
    func execute(request: StartPushEnrollmentRequest) async throws -> PushEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .enrollPushNotification()
            .start()
    }
}
