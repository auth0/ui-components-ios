import Auth0
import Combine

/// Request model for confirming passkey enrollment.
///
/// Contains the newly created passkey and enrollment details needed
/// to complete the passkey registration with Auth0.
///
/// ## See Also
///
/// - [Passkeys](https://auth0.com/docs/secure/multi-factor-authentication/fido-authentication-with-webauthn/configure-webauthn-with-device-biometrics-for-mfa)
/// - [WebAuthn Credentials](https://auth0.com/docs/secure/multi-factor-authentication/fido-authentication-with-webauthn)
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct ConfirmPasskeyEnrollmentRequest {
    /// The newly created passkey from the credential provider. This contains the public key credential
    /// created by the platform's authenticator (Touch ID, Face ID, etc.).
    let passkey: any NewPasskey
    /// Access token for authenticating with Auth0's My Account API
    let token: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// The passkey enrollment challenge received from the start use case. Contains the server-generated
    /// challenge and parameters required for WebAuthn registration.
    let challenge: PasskeyEnrollmentChallenge
}

/// Protocol for the passkey enrollment confirmation use case.
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
protocol ConfirmPasskeyEnrollmentUseCaseable {
    /// Confirms passkey enrollment with the created passkey.
    ///
    /// - Parameter request: The request containing the passkey and challenge
    /// - Returns: The created passkey authentication method
    /// - Throws: Auth0 or network errors if the operation fails
    func execute(request: ConfirmPasskeyEnrollmentRequest) async throws -> PasskeyAuthenticationMethod
}

/// Use case for confirming passkey enrollment.
///
/// Completes the passkey enrollment process by sending the created passkey
/// to Auth0's My Account API for registration. Upon successful confirmation,
/// the passkey can be used for authentication.
///
/// Availability: Requires iOS 16.6, macOS 13.5, or visionOS 1.0+
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct ConfirmPasskeyEnrollmentUseCase: ConfirmPasskeyEnrollmentUseCaseable {
    /// Confirms passkey enrollment with the created passkey.
    ///
    /// - Parameter request: Request containing the new passkey and challenge
    /// - Returns: The enrolled passkey authentication method
    /// - Throws: Auth0APIError if the passkey creation or enrollment fails
    func execute(request: ConfirmPasskeyEnrollmentRequest) async throws -> PasskeyAuthenticationMethod {
        try await Auth0.myAccount(token: request.token, domain: request.domain)
            .authenticationMethods
            .enroll(passkey: request.passkey, challenge: request.challenge)
            .start()
    }
}
