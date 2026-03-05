import SwiftUI

// MARK: - Auth0TextStyle

/// A complete text style that bundles font, letter spacing, and line spacing.
///
/// Every design token in ``Auth0TypographyTokens`` is an `Auth0TextStyle` so
/// that the full spec — typeface, size, weight, tracking, and line height —
/// travels together and is never partially applied.
///
/// Apply the full style in one call using ``SwiftUI/View/auth0TextStyle(_:)``:
///
/// ```swift
/// Text("Almost there!")
///     .auth0TextStyle(theme.typography.body)
///     .foregroundStyle(theme.colors.text.bold)
/// ```
public struct Auth0TextStyle: Sendable {

    /// The font for this style, including typeface, size, weight, and Dynamic Type scaling.
    public let font: Font

    /// Letter spacing in points. Negative values tighten; positive values open.
    public let tracking: CGFloat

    /// Additional vertical space between lines in points (`targetLineHeight − fontSize`).
    public let lineSpacing: CGFloat

    /// Creates a text style.
    ///
    /// - Parameters:
    ///   - font: The `Font` to use. Use `Font.custom(_:size:relativeTo:)` for Dynamic Type scaling.
    ///   - tracking: Letter spacing in points. Default `0`.
    ///   - lineSpacing: Extra vertical space between lines in points. Default `0`.
    public init(font: Font, tracking: CGFloat = 0, lineSpacing: CGFloat = 0) {
        self.font = font
        self.tracking = tracking
        self.lineSpacing = lineSpacing
    }
}

// MARK: - Protocol

/// A contract that defines all typography tokens used by Auth0 UI Components.
///
/// Conform to this protocol to supply a custom typeface:
///
/// ```swift
/// struct BrandTypography: Auth0TypographyTokens {
///     var displayLarge: Auth0TextStyle {
///         Auth0TextStyle(font: .custom("Poppins-SemiBold", size: 34, relativeTo: .largeTitle),
///                        tracking: -0.2, lineSpacing: 7)
///     }
///     // … all remaining required properties
/// }
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(typography: BrandTypography()))
/// ```
public protocol Auth0TypographyTokens: Sendable {

    // MARK: Display

    /// Inter SemiBold 34 pt · line 41 pt · tracking −0.2 pt
    var displayLarge: Auth0TextStyle { get }

    /// Inter SemiBold 28 pt · line 34 pt · tracking −0.1 pt
    var displayMedium: Auth0TextStyle { get }

    /// Inter SemiBold 22 pt · line 28 pt · tracking −0.05 pt
    var display: Auth0TextStyle { get }

    // MARK: Title

    /// Inter SemiBold 20 pt · line 25 pt · tracking 0 pt
    var titleLarge: Auth0TextStyle { get }

    /// Inter SemiBold 17 pt · line 24 pt · tracking 0 pt
    var title: Auth0TextStyle { get }

    // MARK: Body

    /// Inter Regular 17 pt · line 24 pt · tracking 0 pt
    var body: Auth0TextStyle { get }

    /// Inter Regular 15 pt · line 20 pt · tracking 0.1 pt
    var bodySmall: Auth0TextStyle { get }

    // MARK: Label / Helper / Overline

    /// Inter Medium 16 pt · line 21 pt · tracking 0.1 pt
    var label: Auth0TextStyle { get }

    /// Inter Regular 13 pt · line 18 pt · tracking 0.2 pt
    var helper: Auth0TextStyle { get }

    /// Inter Regular 11 pt · line 16 pt · tracking 0.77 pt
    var overline: Auth0TextStyle { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 typography scale using the Inter typeface.
///
/// Three Inter weight files are bundled: **Inter-SemiBold**, **Inter-Medium**, and **Inter-Regular**.
/// Dynamic Type scaling is handled automatically by `Font.custom(_:size:relativeTo:)`.
///
/// Font registration happens automatically the first time this struct is created.
///
/// Pass a custom ``Auth0TextStyle`` only for tokens you need to override:
///
/// ```swift
/// let typography = DefaultAuth0TypographyTokens(
///     body: Auth0TextStyle(font: .custom("Lato-Regular", size: 17, relativeTo: .body),
///                          tracking: 0, lineSpacing: 7)
/// )
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(typography: typography))
/// ```
public struct DefaultAuth0TypographyTokens: Auth0TypographyTokens {

    public var displayLarge: Auth0TextStyle
    public var displayMedium: Auth0TextStyle
    public var display: Auth0TextStyle
    public var titleLarge: Auth0TextStyle
    public var title: Auth0TextStyle
    public var body: Auth0TextStyle
    public var bodySmall: Auth0TextStyle
    public var label: Auth0TextStyle
    public var helper: Auth0TextStyle
    public var overline: Auth0TextStyle

    public init(
        displayLarge: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-SemiBold", size: 34, relativeTo: .largeTitle), tracking: -0.2, lineSpacing: 7),
        displayMedium: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-SemiBold", size: 28, relativeTo: .title), tracking: -0.1, lineSpacing: 6),
        display: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-SemiBold", size: 22, relativeTo: .title2), tracking: -0.05, lineSpacing: 6),
        titleLarge: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-SemiBold", size: 20, relativeTo: .title3), tracking: 0, lineSpacing: 5),
        title: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-SemiBold", size: 17, relativeTo: .headline), tracking: 0, lineSpacing: 7),
        body: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-Regular", size: 17, relativeTo: .body), tracking: 0, lineSpacing: 7),
        bodySmall: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-Regular", size: 15, relativeTo: .subheadline), tracking: 0.1, lineSpacing: 5),
        label: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-Medium", size: 16, relativeTo: .callout), tracking: 0.1, lineSpacing: 5),
        helper: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-Regular", size: 13, relativeTo: .footnote), tracking: 0.2, lineSpacing: 5),
        overline: Auth0TextStyle = Auth0TextStyle(font: .custom("Inter-Regular", size: 11, relativeTo: .caption2), tracking: 0.77, lineSpacing: 5)
    ) {
        Auth0FontRegistration.registerIfNeeded()
        self.displayLarge  = displayLarge
        self.displayMedium = displayMedium
        self.display       = display
        self.titleLarge    = titleLarge
        self.title         = title
        self.body          = body
        self.bodySmall     = bodySmall
        self.label         = label
        self.helper        = helper
        self.overline      = overline
    }
}

// MARK: - View Extension

extension View {

    /// Applies an ``Auth0TextStyle`` to the view — font, letter spacing, and line spacing in one call.
    ///
    /// ```swift
    /// Text("Sign in")
    ///     .auth0TextStyle(theme.typography.label)
    ///     .foregroundStyle(theme.colors.text.onPrimary)
    /// ```
    public func auth0TextStyle(_ style: Auth0TextStyle) -> some View {
        self.font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}
