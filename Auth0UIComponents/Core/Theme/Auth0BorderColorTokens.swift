import SwiftUI

// MARK: - Protocol

/// A contract that defines all border colour tokens used by Auth0 UI Components.
///
/// Border tokens are divided into two sub-groups that mirror the Mobile Design System
/// dot-notation (`color.border.*`):
///
/// ```
/// Border
///   ├── Emphasis   bold · regular · subtle
///   └── Elevation  shadow
/// ```
///
/// > **Note on naming:** Mobile Design System uses `color.border.default` for the standard border
/// > colour. Because `default` is a reserved keyword in Swift, this token
/// > is named `regular` here.
///
/// Conform to this protocol to supply custom border colours from your app's asset catalog:
///
/// ```swift
/// struct BrandBorder: Auth0BorderColorTokens {
///     var bold:    Color { Color("Border/Bold",    bundle: .main) }
///     var regular: Color { Color("Border/Default", bundle: .main) }
///     var subtle:  Color { Color("Border/Subtle",  bundle: .main) }
///     var shadow:  Color { Color("Border/Shadow",  bundle: .main) }
/// }
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: DefaultAuth0ColorTokens(border: BrandBorder())))
/// ```
public protocol Auth0BorderColorTokens: Sendable {

    // MARK: - Emphasis

    /// High-contrast border for emphasis, strong separation, or selected elements.
    /// Mobile Design System: `color.border.bold`
    var bold: Color { get }

    /// Standard border colour for most UI elements and containers.
    /// Mobile Design System: `color.border.default`
    var regular: Color { get }

    /// Low-contrast border for delicate dividers and understated boundaries.
    /// Mobile Design System: `color.border.subtle`
    var subtle: Color { get }

    // MARK: - Elevation

    /// Border-like shadow colour for depth and elevation cues.
    /// Mobile Design System: `color.border.shadow`
    var shadow: Color { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 border colour tokens.
///
/// Defaults are sourced from the `Border/` namespace in `Colors.xcassets`.
/// Every colorset is adaptive — it carries both a light-mode and a dark-mode swatch.
///
/// Pass values to the initialiser for any tokens you need to customise:
///
/// ```swift
/// let border = DefaultAuth0BorderColorTokens(regular: Color("Border/Default", bundle: .main))
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: DefaultAuth0ColorTokens(border: border)))
/// ```
public struct DefaultAuth0BorderColorTokens: Auth0BorderColorTokens {

    // MARK: - Emphasis

    public var bold:    Color
    public var regular: Color
    public var subtle:  Color

    // MARK: - Elevation

    public var shadow: Color

    // MARK: - Init

    public init(
        // Emphasis
        bold:    Color = Color("Border/Bold",    bundle: ResourceBundle.default),
        regular: Color = Color("Border/Default", bundle: ResourceBundle.default),
        subtle:  Color = Color("Border/Subtle",  bundle: ResourceBundle.default),
        // Elevation
        shadow:  Color = Color("Border/Shadow",  bundle: ResourceBundle.default)
    ) {
        // Emphasis
        self.bold    = bold
        self.regular = regular
        self.subtle  = subtle
        // Elevation
        self.shadow  = shadow
    }
}
