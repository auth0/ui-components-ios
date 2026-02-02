import Auth0

/// Request model for initiating passkey enrollment.
///
/// Contains the authentication token, Auth0 domain, and optional configuration
/// for passkey enrollment.
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct StartPasskeyEnrollmentRequest {
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// Optional user identity ID for the passkey enrollment
    let userIdentityId: String?
    /// Optional connection name for the passkey
    let connection: String?
}

/// Protocol for the passkey enrollment initiation use case.
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
protocol StartPasskeyEnrollmentUseCaseable {
    /// Initiates passkey enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: The request containing token and domain
    /// - Returns: A PasskeyEnrollmentChallenge for creating the passkey
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: StartPasskeyEnrollmentRequest) async throws -> PasskeyEnrollmentChallenge
}

/// Use case for starting passkey enrollment.
///
/// Initiates the passkey enrollment process by requesting a challenge from
/// Auth0's My Account API. The challenge is then used to create a new passkey
/// via the platform's credential provider.
///
/// Availability: Requires iOS 16.6, macOS 13.5, or visionOS 1.0+
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct StartPasskeyEnrollmentUseCase: StartPasskeyEnrollmentUseCaseable {
    /// Starts passkey enrollment and returns the enrollment challenge.
    ///
    /// - Parameter request: Request containing authentication token and domain
    /// - Returns: Passkey enrollment challenge
    /// - Throws: Auth0APIError if the request fails
    func execute(request: StartPasskeyEnrollmentRequest) async throws -> PasskeyEnrollmentChallenge {
        try await Auth0.myAccount(token: request.token, domain: request.domain)
            .authenticationMethods
            .passkeyEnrollmentChallenge()
            .start()
    }
}
