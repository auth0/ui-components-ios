import Foundation
import Auth0

/// A singleton actor that manages Auth0 SDK configuration and dependencies.
/// 
/// Auth0UIComponentsSDKInitializer must be initialized once in your app's entry point before using any SDK components.
/// It provides centralized access to configuration values, token provider, and network session.
/// 
/// Thread-safe due to actor isolation.
/// 
/// Once initialized, the shared instance is guaranteed to be non-nil and accessible throughout the app's lifetime.
public actor Auth0UIComponentsSDKInitializer {
    // MARK: - Properties
    
    /// The Auth0 Management API audience (typically domain/me/).
    let audience: String
    
    /// The Auth0 tenant domain (e.g., "your-tenant.auth0.com").
    let domain: String
    
    /// The Auth0 application client ID.
    let clientId: String
    
    /// Token provider for obtaining and managing access tokens.
    let tokenProvider: TokenProvider
    
    /// Bundle containing Auth0.plist configuration file.
    let bundle: Bundle
    
    /// URLSession used for network requests.
    let session: URLSession

    // MARK: - Shared Instance
    
    /// Stores the singleton instance of Auth0UIComponentsSDKInitializer.
    /// This is guaranteed to be non-nil after successful initialization.
    /// Access via the `shared` property instead of directly.
    static private var _shared: Auth0UIComponentsSDKInitializer?

    /// Returns the initialized Auth0UIComponentsSDKInitializer singleton instance.
    /// 
    /// This property is guaranteed to be non-nil after `initialize()` has been called successfully.
    /// The shared instance is created once and reused throughout the app's lifetime.
    /// 
    /// - Note: Accessing this before calling `initialize()` will result in a runtime crash.
    ///   Ensure you call one of the `initialize()` methods in your app's entry point before
    ///   using any UI components that depend on Auth0UIComponentsSDKInitializer.
    static var shared: Auth0UIComponentsSDKInitializer {
        guard let instance = _shared else {
            fatalError("Auth0UIComponentsSDKInitializer not initialized. Call Auth0UIComponentsSDKInitializer.initialize(...) first!")
        }
        return instance
    }

    // MARK: - Initialization
    
    /// Private initializer to create an Auth0UIComponentsSDKInitializer instance.
    /// Use `initialize()` class methods instead of this directly.
    ///
    /// - Parameters:
    ///   - audience: The Auth0 Management API audience URL
    ///   - domain: The Auth0 tenant domain
    ///   - clientId: The Auth0 application client ID
    ///   - bundle: Bundle containing configuration (defaults to .main)
    ///   - session: URLSession for network requests (defaults to .shared)
    ///   - tokenProvider: Provider for access tokens
    private init(audience: String,
                 domain: String,
                 clientId: String,
                 bundle: Bundle = .main,
                 session: URLSession = .shared,
                 tokenProvider: any TokenProvider) {
        self.audience = audience
        self.domain = domain
        self.clientId = clientId
        self.tokenProvider = tokenProvider
        self.bundle = bundle
        self.session = session
    }

    // MARK: - Initialize with Plist
    
    /// Initializes Auth0UIComponentsSDKInitializer from Auth0.plist configuration file.
    ///
    /// This is the recommended initialization method. Ensure Auth0.plist exists in your
    /// app bundle with 'Domain' and 'ClientId' entries.
    ///
    /// Call this method once in your app's entry point (e.g., in the App initializer):
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     init() {
    ///         do {
    ///             try Auth0UIComponentsSDKInitializer.initialize(tokenProvider: myTokenProvider)
    ///         } catch {
    ///             print("Failed to initialize: \(error)")
    ///         }
    ///     }
    ///     var body: some Scene {
    ///         WindowGroup {
    ///             ContentView()
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - session: URLSession for network requests (defaults to .shared)
    ///   - bundle: Bundle to search for Auth0.plist (defaults to .main)
    ///   - tokenProvider: Provider for obtaining access tokens
    ///
    /// - Throws: Auth0UIComponentsSDKInitializerError if initialization fails (plist not found or missing required keys)
    public static func initialize(session: URLSession = .shared,
                                  bundle: Bundle = .main,
                                  tokenProvider: any TokenProvider) {
        // Load configuration from plist file
        let config = plistValues(bundle: bundle)!

        // Construct audience URL from domain
        let myAccountAudience = config.domain.appending("/me/")
        
        // Create and store the shared instance
        _shared = Auth0UIComponentsSDKInitializer(audience: ensureHTTPS(myAccountAudience),
                                    domain: config.domain,
                                    clientId: config.clientId,
                                    bundle: bundle,
                                    session: session,
                                    tokenProvider: tokenProvider)
    }

    // MARK: - Initialize Programmatically
    
    /// Initializes Auth0UIComponentsSDKInitializer with explicitly provided configuration values.
    ///
    /// Use this method if you prefer to configure the SDK programmatically instead of
    /// using Auth0.plist.
    ///
    /// Call this method once in your app's entry point:
    /// ```swift
    /// @main
    /// struct MyApp: App {
    ///     init() {
    ///      Auth0UIComponentsSDKInitializer.initialize(
    ///                 domain: "your-tenant.auth0.com",
    ///                 clientId: "YOUR_CLIENT_ID",
    ///                 audience: "https://your-tenant.auth0.com/api/v2/",
    ///                 tokenProvider: myTokenProvider
    ///             )
    ///     }
    ///     var body: some Scene { ... }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - session: URLSession for network requests (defaults to .shared)
    ///   - bundle: Bundle for resource access (defaults to .main)
    ///   - domain: Auth0 tenant domain (e.g., "your-tenant.auth0.com")
    ///   - clientId: Auth0 application client ID
    ///   - audience: Auth0 Management API audience URL
    ///   - tokenProvider: Provider for obtaining access tokens
    ///
    /// - Throws: Auth0UIComponentsSDKInitializerError if already initialized
    public static func initialize(session: URLSession = .shared,
                                  bundle: Bundle = .main,
                                  domain: String,
                                  clientId: String,
                                  audience: String,
                                  tokenProvider: any TokenProvider) {
        // Create and store the shared instance
        _shared = Auth0UIComponentsSDKInitializer(audience: ensureHTTPS(audience),
                                    domain: domain,
                                    clientId: clientId,
                                    bundle: bundle,
                                    session: session,
                                    tokenProvider: tokenProvider)
    }

    // MARK: - Reset
    
    /// Resets the shared instance to nil.
    /// 
    /// Use this method only in testing scenarios or when you need to reinitialize.
    /// In production apps, the SDK should only be initialized once at app launch.
    ///
    /// After calling reset(), you must call `initialize()` again before using the SDK.
    static func reset() {
        _shared = nil
    }
}

// MARK: - Helper Functions

/// Ensures a URL string starts with "https://" scheme.
///
/// If the URL already has "https://", it's returned unchanged.
/// Otherwise, "https://" is prepended.
///
/// - Parameter urlString: The URL string to process
/// - Returns: URL string with https:// scheme
private func ensureHTTPS(_ urlString: String) -> String {
    if urlString.lowercased().hasPrefix("https://") {
        return urlString
    } else {
        return "https://" + urlString
    }
}

/// Loads Auth0 configuration values from Auth0.plist file.
///
/// Auth0.plist must contain the following keys:
/// - "Domain": The Auth0 tenant domain (e.g., "your-tenant.auth0.com")
/// - "ClientId": The Auth0 application client ID
///
/// If the plist file or required keys are not found, nil is returned and an error message is printed.
///
/// - Parameter bundle: Bundle to search for Auth0.plist
/// - Returns: Tuple of (clientId, domain) if found, nil otherwise
private func plistValues(bundle: Bundle) -> (clientId: String, domain: String)? {
    // Attempt to load plist file from bundle
    guard let path = bundle.path(forResource: "Auth0", ofType: "plist"),
          let values = NSDictionary(contentsOfFile: path) as? [String: Any] else {
        print("Missing Auth0.plist file with 'ClientId' and 'Domain' entries in main bundle!")
        return nil
    }

    // Extract required configuration entries
    guard let clientId = values["ClientId"] as? String, 
          let domain = values["Domain"] as? String else {
        print("Auth0.plist file is missing 'ClientId' and/or 'Domain' entries!")
        return nil
    }
    
    return (clientId: clientId, domain: domain)
}
