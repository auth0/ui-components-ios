import SwiftUI

/// Foreground colours for content that isn't body text: links and, later, other brand accents drawn over a surface.
///
/// A brand sets its own by supplying them to ``DefaultAuth0ColorTokens``:
///
/// ```swift
/// let foreground = DefaultAuth0ForegroundColorTokens(linkPrimary: Color("BrandPurple"))
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: DefaultAuth0ColorTokens(foreground: foreground)))
/// ```
public protocol Auth0ForegroundColorTokens: Sendable {

    /// The brand's primary link colour: "Sign up" and "Log in" under the Embedded Login field.
    var linkPrimary: Color { get }

    /// A confirmation drawn over a surface: the check on the "verified" and "signed in" screens.
    var success: Color { get }

    /// Error text, digits and cursor in Embedded Login.
    var error: Color { get }
}

/// The built-in Auth0 foreground colour tokens, sourced from the `Foreground/` namespace in `Colors.xcassets`.
public struct DefaultAuth0ForegroundColorTokens: Auth0ForegroundColorTokens {

    public var linkPrimary: Color
    public var success: Color
    public var error: Color

    /// - Parameters:
    ///   - linkPrimary: Defaults to `Foreground/Link Primary` (#9921FE, a lighter purple in dark mode).
    ///   - success: Defaults to `Foreground/Success` (#218C4D, a lighter green in dark mode).
    ///   - error: Defaults to `Foreground/Error` (#CA3B2B, a lighter red in dark mode).
    public init(linkPrimary: Color = Color("Foreground/LinkPrimary", bundle: ResourceBundle.default),
                success: Color = Color("Foreground/Success", bundle: ResourceBundle.default),
                error: Color = Color("Foreground/Error", bundle: ResourceBundle.default)) {
        self.linkPrimary = linkPrimary
        self.success = success
        self.error = error
    }
}
