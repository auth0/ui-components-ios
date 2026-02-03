import Foundation
import Auth0

/// The central initializer for Auth0 UI Components SDK.
///
/// This actor manages the global configuration and dependencies required for Auth0 UI Components to function.
/// It must be initialized before any Auth0 UI Components views are displayed. All configuration is done through
/// initialization methods that can read configuration from Auth0.plist or accept parameters directly.
///
/// Example with Auth0.plist configuration:
/// ```swift
/// // In your SceneDelegate or App initialization
/// struct MyApp: App {
///     init() {
///         let tokenProvider = MyTokenProvider()
///         Auth0UIComponentsSDKInitializer.initialize(tokenProvider: tokenProvider)
///     }
///
///     var body: some Scene {
///         WindowGroup {
///             MyAccountAuthMethodsView()
///         }
///     }
/// }
/// ```
///
/// Example with explicit configuration:
/// ```swift
/// let tokenProvider = MyTokenProvider()
/// Auth0UIComponentsSDKInitializer.initialize(
///     domain: "example.auth0.com",
///     clientId: "YOUR_CLIENT_ID",
///     audience: "https://example.auth0.com/me/",
///     tokenProvider: tokenProvider
/// )
///
/// // Later, access the initialized SDK
/// let config = Auth0UIComponentsSDKInitializer.shared
/// ```
///
/// Dependencies:
/// - TokenProvider: Must conform to the TokenProvider protocol to handle credential management
/// - Auth0UIComponents can read configuration from Auth0.plist (ClientId, Domain) or accept them directly
public actor Auth0UIComponentsSDKInitializer {
    /// The audience for My Account API requests (typically domain/me/)
    let audience: String
    /// Auth0 tenant domain (e.g., "example.auth0.com")
    let domain: String
    /// Auth0 application client ID
    let clientId: String
    /// Configuration for passkey enrollment behavior
    let passkeyConfiguration: PasskeysConfiguration
    /// Provider for fetching and managing authentication credentials
    let tokenProvider: TokenProvider
    /// Bundle for accessing framework resources
    let bundle: Bundle
    /// URLSession for making HTTP requests
    let session: URLSession
    static private var _shared: Auth0UIComponentsSDKInitializer?

    /// Access the shared singleton instance of Auth0UIComponentsSDKInitializer.
    ///
    /// - Precondition: The initializer must have been called before accessing this property, otherwise a fatal error occurs.
    /// - Returns: The shared Auth0UIComponentsSDKInitializer instance
    static var shared: Auth0UIComponentsSDKInitializer {
        guard let instance = _shared else {
            fatalError("Auth0UIComponentsSDKInitializer not initialized. Call Auth0UIComponentsSDKInitializer.initialize(...) first!")
        }
        return instance
    }

    private init(audience: String,
                 domain: String,
                 clientId: String,
                 passkeyConfiguration: PasskeysConfiguration,
                 bundle: Bundle = .main,
                 session: URLSession = .shared,
                 tokenProvider: any TokenProvider) {
        self.audience = audience
        self.domain = domain
        self.clientId = clientId
        self.tokenProvider = tokenProvider
        self.bundle = bundle
        self.session = session
        self.passkeyConfiguration = passkeyConfiguration
    }

    /// Initialize the SDK using configuration from Auth0.plist.
    ///
    /// This method reads the ClientId and Domain from the Auth0.plist file in the main bundle.
    /// The plist file must contain "ClientId" and "Domain" keys.
    ///
    /// - Parameters:
    ///   - session: The URLSession to use for network requests (defaults to .shared)
    ///   - passkeyConfiguration: Configuration for passkey enrollment behavior
    ///   - bundle: The bundle to read Auth0.plist from (defaults to .main)
    ///   - tokenProvider: Provider for fetching and managing authentication credentials
    ///
    /// - Throws: Calls fatalError if Auth0.plist is not found or is missing required keys
    public static func initialize(session: URLSession = .shared,
                                  passkeyConfiguration: PasskeysConfiguration = PasskeysConfiguration(),
                                  bundle: Bundle = .main,
                                  tokenProvider: any TokenProvider) {
        let config = plistValues(bundle: bundle)!

        let myAccountAudience = config.domain.appending("/me/")

        _shared = Auth0UIComponentsSDKInitializer(audience: ensureHTTPS(myAccountAudience),
                                                  domain: config.domain,
                                                  clientId: config.clientId,
                                                  passkeyConfiguration: passkeyConfiguration,
                                                  bundle: bundle,
                                                  session: session,
                                                  tokenProvider: tokenProvider)
    }

    /// Initialize the SDK with explicit configuration parameters.
    ///
    /// This method allows you to provide configuration parameters directly instead of reading from a plist file.
    ///
    /// - Parameters:
    ///   - session: The URLSession to use for network requests (defaults to .shared)
    ///   - bundle: The bundle to read resources from (defaults to .main)
    ///   - domain: Auth0 tenant domain (e.g., "example.auth0.com")
    ///   - clientId: Auth0 application client ID
    ///   - passkeyConfiguration: Configuration for passkey enrollment behavior
    ///   - audience: The audience for API requests (typically domain/me/)
    ///   - tokenProvider: Provider for fetching and managing authentication credentials
    public static func initialize(session: URLSession = .shared,
                                  bundle: Bundle = .main,
                                  domain: String,
                                  clientId: String,
                                  passkeyConfiguration: PasskeysConfiguration = PasskeysConfiguration(),
                                  audience: String,
                                  tokenProvider: any TokenProvider) {
        _shared = Auth0UIComponentsSDKInitializer(audience: ensureHTTPS(audience),
                                    domain: domain,
                                    clientId: clientId,
                                    passkeyConfiguration: passkeyConfiguration,
                                    bundle: bundle,
                                    session: session,
                                    tokenProvider: tokenProvider)
    }

    /// Reset the SDK to an uninitialized state.
    ///
    /// This is primarily used for testing purposes to clear the singleton instance.
    static func reset() {
        _shared = nil
    }
}

/// Ensures a URL string has an HTTPS scheme.
///
/// If the URL string already has an https:// prefix, it is returned as-is.
/// Otherwise, "https://" is prepended to the string.
///
/// - Parameter urlString: The URL string to process
/// - Returns: A URL string with an https:// prefix
private func ensureHTTPS(_ urlString: String) -> String {
    if urlString.lowercased().hasPrefix("https://") {
        return urlString
    } else {
        return "https://" + urlString
    }
}

/// Reads Auth0 configuration from the Auth0.plist file.
///
/// Attempts to load the Auth0.plist file from the specified bundle and extract
/// the "ClientId" and "Domain" keys.
///
/// - Parameter bundle: The bundle to search for Auth0.plist
/// - Returns: A tuple containing (clientId, domain) if successful, nil if the plist is missing or incomplete
///
/// - Note: Prints error messages to console if the plist file is not found or is missing required keys
private func plistValues(bundle: Bundle) -> (clientId: String, domain: String)? {
    guard let path = bundle.path(forResource: "Auth0", ofType: "plist"),
          let values = NSDictionary(contentsOfFile: path) as? [String: Any] else {
        print("Missing Auth0.plist file with 'ClientId' and 'Domain' entries in main bundle!")
        return nil
    }

    guard let clientId = values["ClientId"] as? String,
          let domain = values["Domain"] as? String else {
        print("Auth0.plist file is missing 'ClientId' and/or 'Domain' entries!")
        return nil
    }

    return (clientId: clientId, domain: domain)
}
