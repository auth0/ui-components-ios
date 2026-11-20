import SwiftUI

/// The brand's own assets: what an Auth0 screen shows to say whose it is. The defaults are Auth0's. A customer replaces
/// them by supplying their own, once, in the theme.
///
/// ```swift
/// let brand = DefaultAuth0BrandTokens(logo: Image("AcmeLogo"), logoLabel: "Acme")
/// ContentView()
///     .auth0Theme(Auth0Theme(brand: brand))
/// ```
public protocol Auth0BrandTokens: Sendable {

    /// The logo shown above the title of the Embedded Login and sign-up entry screens. A template image
    /// takes the colour of the text around it, which is what keeps the default readable in dark mode; give it
    /// `.renderingMode(.original)` to keep its own colours.
    var logo: Image { get }

    /// What VoiceOver says for the logo.
    var logoLabel: String { get }
}

/// The built-in Auth0 brand assets.
public struct DefaultAuth0BrandTokens: Auth0BrandTokens {

    public var logo: Image
    public var logoLabel: String

    /// - Parameters:
    ///   - logo: Defaults to the Auth0 logo.
    ///   - logoLabel: Defaults to `"Auth0"`.
    public init(logo: Image = Image("auth0_logo", bundle: ResourceBundle.default), logoLabel: String = "Auth0") {
        self.logo = logo
        self.logoLabel = logoLabel
    }
}
