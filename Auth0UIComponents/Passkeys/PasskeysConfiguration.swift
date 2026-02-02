/// Configuration options for passkey enrollment behavior.
///
/// This struct allows customization of how passkeys are enrolled and managed
/// in the application. It provides optional identity and connection information.
///
/// Example:
/// ```swift
/// // Create a basic passkey configuration
/// let basicConfig = PasskeysConfiguration()
///
/// // Create a configuration with specific identity and connection
/// let customConfig = PasskeysConfiguration(
///     userIdentityId: "auth0|12345",
///     connection: "Username-Password-Authentication"
/// )
///
/// // Use with SDK initialization
/// Auth0UIComponentsSDKInitializer.initialize(
///     domain: "example.auth0.com",
///     clientId: "YOUR_CLIENT_ID",
///     audience: "https://example.auth0.com/me/",
///     passkeyConfiguration: customConfig,
///     tokenProvider: myTokenProvider
/// )
/// ```
public struct PasskeysConfiguration {
    /// The user's identity ID for passkey enrollment (optional)
    let userIdentityId: String?
    /// The connection to use for passkey operations (optional)
    let connection: String?

    /// Initializes the passkey configuration.
    ///
    /// - Parameters:
    ///   - userIdentityId: The user's identity ID. The identity ID to link the passkey to.
    ///   This is typically the `sub` claim from the user's ID token. (defaults to nil)
    ///   - connection: The connection name for passkey operations. Specifies the database connection
    ///   to use when enrolling the passkey. (defaults to nil)
    ///
    /// ## See Also
    ///
    /// - [Passkeys](https://auth0.com/docs/secure/multi-factor-authentication/fido-authentication-with-webauthn/configure-webauthn-with-device-biometrics-for-mfa)
    /// - [User Identity](https://auth0.com/docs/manage-users/user-accounts/identify-users)
    /// - [Database Connections](https://auth0.com/docs/authenticate/database-connections)
    public init(userIdentityId: String? = nil,
                connection: String? = nil) {
        self.userIdentityId = userIdentityId
        self.connection = connection
    }
}
