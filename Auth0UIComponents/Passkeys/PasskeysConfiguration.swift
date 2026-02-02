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
    ///   - userIdentityId: The user's identity ID (defaults to nil)
    ///   - connection: The connection name for passkey operations (defaults to nil)
    public init(userIdentityId: String? = nil,
                connection: String? = nil) {
        self.userIdentityId = userIdentityId
        self.connection = connection
    }
}
