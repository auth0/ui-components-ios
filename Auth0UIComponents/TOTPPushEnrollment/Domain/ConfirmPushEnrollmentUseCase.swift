import Auth0
import Foundation
import Combine

/// Request model for confirming push notification enrollment.
///
/// Contains the enrollment session information needed to complete
/// the push notification authentication method enrollment.
struct ConfirmPushEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// The enrollment ID from the initial challenge
    let id: String
    /// The authentication session identifier from the challenge
    let authSession: String
}

/// Protocol for the push notification enrollment confirmation use case.
protocol ConfirmPushEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession { get }
    /// Confirms push notification enrollment.
    ///
    /// - Parameter request: The request containing enrollment details
    /// - Returns: The created authentication method
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: ConfirmPushEnrollmentRequest) async throws -> AuthenticationMethod
}

/// Use case for confirming push notification authentication enrollment.
///
/// Completes the push notification enrollment process by confirming the
/// enrollment session. Upon successful confirmation, push notifications
/// can be used for authentication.
struct ConfirmPushEnrollmentUseCase: ConfirmPushEnrollmentUseCaseable {
    /// The URLSession used for network requests
    var session: URLSession

    /// Initializes the use case with an optional URLSession.
    ///
    /// - Parameter session: The URLSession to use for requests (defaults to .shared)
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Confirms push notification enrollment.
    ///
    /// - Parameter request: Request containing enrollment details
    /// - Returns: The newly created push notification authentication method
    /// - Throws: Auth0APIError if the request fails
    func execute(request: ConfirmPushEnrollmentRequest) async throws -> AuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain, session: session)
            .authenticationMethods
            .confirmPushNotificationEnrollment(id: request.id, authSession: request.authSession)
            .start()
    }
}
