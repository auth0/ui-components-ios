import SwiftUI

// MARK: - Protocol

/// A contract that defines all text colour tokens used by Auth0 UI Components.
///
/// Text tokens are divided into two sub-groups that mirror the Mobile Design System
/// dot-notation (`color.text.*`):
///
/// ```
/// Text
///   ├── Content   bold · regular · disabled
///   └── On Color  onPrimary · onSuccess · onError
/// ```
///
/// > **Note on naming:** Mobile Design System uses `color.text.default` for the regular-weight
/// > text colour. Because `default` is a reserved keyword in Swift, this token
/// > is named `regular` here.
///
/// Conform to this protocol to supply custom text colours from your app's asset catalog:
///
/// ```swift
/// struct BrandText: Auth0TextColorTokens {
///     var bold:      Color { Color("Text/Bold",      bundle: .main) }
///     var regular:   Color { Color("Text/Default",   bundle: .main) }
///     var disabled:  Color { Color("Text/Disabled",  bundle: .main) }
///     var onPrimary: Color { Color("Text/OnPrimary", bundle: .main) }
///     var onSuccess: Color { Color("Text/OnSuccess", bundle: .main) }
///     var onError:   Color { Color("Text/OnError",   bundle: .main) }
/// }
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: DefaultAuth0ColorTokens(text: BrandText())))
/// ```
public protocol Auth0TextColorTokens: Sendable {

    // MARK: - Content

    /// High-emphasis text — default body and heading text on neutral surfaces.
    /// Mobile Design System: `color.text.bold`
    var bold: Color { get }

    /// Lower-emphasis text — helper text, captions, and secondary information.
    /// Mobile Design System: `color.text.default`
    var regular: Color { get }

    /// Colour for disabled and placeholder text.
    /// Mobile Design System: `color.text.disabled`
    var disabled: Color { get }

    // MARK: - On Color

    /// Colour for text and icons placed on top of a `background.primary` surface.
    /// Mobile Design System: `color.text.onPrimary`
    var onPrimary: Color { get }

    /// Colour for text and icons placed on top of a `background.success` surface.
    /// Mobile Design System: `color.text.onSuccess`
    var onSuccess: Color { get }

    /// Colour for text and icons placed on top of a `background.error` surface.
    /// Mobile Design System: `color.text.onError`
    var onError: Color { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 text colour tokens.
///
/// Defaults are sourced from the `Text/` namespace in `Colors.xcassets`.
/// Every colorset is adaptive — it carries both a light-mode and a dark-mode swatch.
///
/// Pass values to the initialiser for any tokens you need to customise:
///
/// ```swift
/// let text = DefaultAuth0TextColorTokens(bold: Color("Text/Bold", bundle: .main))
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: DefaultAuth0ColorTokens(text: text)))
/// ```
public struct DefaultAuth0TextColorTokens: Auth0TextColorTokens {

    // MARK: - Content

    public var bold:     Color
    public var regular:  Color
    public var disabled: Color

    // MARK: - On Color

    public var onPrimary: Color
    public var onSuccess: Color
    public var onError:   Color

    // MARK: - Init

    public init(
        // Content
        bold:      Color = Color("Text/Bold",      bundle: ResourceBundle.default),
        regular:   Color = Color("Text/Default",   bundle: ResourceBundle.default),
        disabled:  Color = Color("Text/Disabled",  bundle: ResourceBundle.default),
        // On Color
        onPrimary: Color = Color("Text/OnPrimary", bundle: ResourceBundle.default),
        onSuccess: Color = Color("Text/OnSuccess", bundle: ResourceBundle.default),
        onError:   Color = Color("Text/OnError",   bundle: ResourceBundle.default)
    ) {
        // Content
        self.bold     = bold
        self.regular  = regular
        self.disabled = disabled
        // On Color
        self.onPrimary = onPrimary
        self.onSuccess = onSuccess
        self.onError   = onError
    }
}
