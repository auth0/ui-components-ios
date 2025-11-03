import SwiftUI
import Auth0

/// Creates and initializes the main authentication view for 'My Account' settings by loading
/// configuration from the application's `Auth0.plist` file.
///
/// This factory function simplifies setup by relying on standard bundle configuration.
/// It automatically constructs the audience URI based on the domain found in the plist
/// by appending `/me/` to it.
///
/// - Parameters:
///   - session: The URLSession to be used for network requests within the view model. Defaults to `URLSession.shared`.
///   - bundle: The bundle used for loading local assets like images and colors within the view. Defaults to `.main`.
///   - tokenProvider: An object conforming to ``TokenProvider`` responsible for fetching and storing
///                    authentication tokens.
/// - Returns: A configured `MyAccountAuthMethodsView` ready for display.
@MainActor
public func myAcountAuthView(session: URLSession = .shared,
                             bundle: Bundle = .main,
                             tokenProvider: any TokenProvider) -> some View {
    let config = plistValues(bundle: Bundle.main)!
    let myAccountAudience = config.domain.appending("/me/")
    Dependencies.initialize(audience: ensureHTTPS(myAccountAudience),
                            domain: config.domain,
                            clientId: config.clientId,
                            bundle: bundle,
                            session: session,
                            tokenProvider: tokenProvider)
    return MyAccountAuthMethodsView(viewModel: MyAccountAuthMethodsViewModel(session: session))
}

/// Creates and initializes the main authentication view for 'My Account' settings using
/// explicitly provided configuration values.
///
/// This overload is useful for environments where configuration is managed dynamically, such
/// as during testing, or when the `Auth0.plist` file is not available.
///
/// - Parameters:
///   - session: The URLSession to be used for network requests within the view model. Defaults to `URLSession.shared`.
///   - bundle: The bundle used for loading local assets like images and colors within the view. Defaults to `.main`.
///   - domain: The Auth0 domain (e.g., `your-tenant.auth0.com`).
///   - clientId: The Auth0 Client ID for the application.
///   - audience: The specific audience URI for the 'My Account' API (e.g., `https://your-tenant.auth0.com/me/`).
///   - tokenProvider: An object conforming to ``TokenProvider`` responsible for fetching and storing
///                    authentication tokens.
/// - Returns: A configured `MyAccountAuthMethodsView` ready for display.
@MainActor
public func myAcountAuthView(session: URLSession = .shared,
                             bundle: Bundle = .main,
                             domain: String,
                             clientId: String,
                             audience: String,
                             tokenProvider: any TokenProvider) -> some View {
    Dependencies.initialize(audience: ensureHTTPS(audience),
                            domain: domain,
                            clientId: clientId,
                            bundle: bundle,
                            session: session,
                            tokenProvider: tokenProvider)
    return MyAccountAuthMethodsView(viewModel: MyAccountAuthMethodsViewModel(session: session))
}

/// Ensures a given URL string uses the secure HTTPS protocol prefix.
///
/// If the string is already prefixed with `https://`, it is returned unchanged.
/// Otherwise, `https://` is prepended to the string.
///
/// - Parameter urlString: The URL string to check and format.
/// - Returns: The guaranteed HTTPS URL string.
func ensureHTTPS(_ urlString: String) -> String {
    if urlString.lowercased().hasPrefix("https://") {
        return urlString
    } else {
        return "https://" + urlString
    }
}

/// Reads the required configuration values (`ClientId` and `Domain`) from the `Auth0.plist` file.
///
/// This function looks for the `Auth0.plist` file within the specified bundle.
/// If the file is missing or required keys are absent, it logs an error and returns `nil`.
///
/// - Parameter bundle: The bundle to search for the `Auth0.plist` file.
/// - Returns: A tuple containing `clientId` and `domain` strings, or `nil` if the configuration cannot be read.
func plistValues(bundle: Bundle) -> (clientId: String, domain: String)? {
    guard let path = bundle.path(forResource: "Auth0", ofType: "plist"),
          let values = NSDictionary(contentsOfFile: path) as? [String: Any] else {
        print("Missing Auth0.plist file with 'ClientId' and 'Domain' entries in main bundle!")
        return nil
    }
    
    guard let clientId = values["ClientId"] as? String, let domain = values["Domain"] as? String else {
        print("Auth0.plist file at \(path) is missing 'ClientId' and/or 'Domain' entries!")
        print("File currently has the following entries: \(values)")
        return nil
    }
    return (clientId: clientId, domain: domain)
}
