import SwiftUI

// MARK: - Protocol

/// A contract that defines all semantic colour tokens used by Auth0 UI Components.
///
/// The SDK uses a two-layer colour system:
///
/// 1. **Palette** — `Colors.xcassets` contains a 12-step Neutral, Red, and Green
///    scale.  Each step is an adaptive colorset with a light-mode and a dark-mode
///    swatch baked in (e.g. `Neutral/12` is `#1F1F1F` in light, `#EEEEEE` in dark).
/// 2. **Semantic tokens** — This protocol maps meaningful roles (`primary`,
///    `onError`, `textSecondary`, …) onto palette entries.  Only this layer is
///    part of the public API.
///
/// ``DefaultAuth0ColorTokens`` performs the default palette → semantic mapping.
/// Its init exposes every token as a parameter so you can override individual
/// tokens without reimplementing the whole protocol:
///
/// ```swift
/// let colors = DefaultAuth0ColorTokens(primary: Brand.primary, onPrimary: Brand.onPrimary)
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: colors))
/// ```
///
/// For full control, implement the protocol and supply your own mapping:
///
/// ```swift
/// struct BrandColors: Auth0ColorTokens {
///     var primary: Color           { Brand.primary }
///     var onPrimary: Color         { Brand.onPrimary }
///     var background: Color        { Brand.background }
///     var surface: Color           { Brand.surface }
///     var onSurface: Color         { Brand.onSurface }
///     var border: Color            { Brand.border }
///     var error: Color             { Brand.error }
///     var errorContainer: Color    { Brand.errorContainer }
///     var onError: Color           { Brand.onError }
///     var success: Color           { Brand.success }
///     var onSuccess: Color         { Brand.onSuccess }
///     var successContainer: Color  { Brand.successContainer }
///     var textPrimary: Color       { Brand.textPrimary }
///     var textSecondary: Color     { Brand.textSecondary }
/// }
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: BrandColors()))
/// ```
public protocol Auth0ColorTokens: Sendable {

    // MARK: Primary

    /// CTA button background and primary border stroke.
    var primary: Color { get }

    /// Text and icon colour rendered on top of a ``primary`` background.
    var onPrimary: Color { get }

    // MARK: Surfaces

    /// The app's main background colour.
    var background: Color { get }

    /// Card and container surface colour, typically matching ``background``.
    var surface: Color { get }

    /// Text and icon colour rendered on top of a ``surface`` background.
    var onSurface: Color { get }

    // MARK: Borders

    /// Stroke colour for input fields and cards.
    var border: Color { get }

    // MARK: Feedback — Error

    /// Container background for error states.
    var error: Color { get }

    /// Subtle background tint for error banner areas.
    var errorContainer: Color { get }

    /// Text and icon colour rendered on top of an ``error`` or ``errorContainer`` surface.
    var onError: Color { get }

    // MARK: Feedback — Success

    /// Container background for success states.
    var success: Color { get }

    /// Subtle background tint for success banner areas.
    var successContainer: Color { get }

    /// Text and icon colour rendered on top of a ``success`` or ``successContainer`` surface.
    var onSuccess: Color { get }

    // MARK: Text

    /// Main heading and body text.
    var textPrimary: Color { get }

    /// Secondary body copy, descriptions, and captions.
    var textSecondary: Color { get }
    
    // MARK: - Card
    
    /// Card icon foreground color.
    var foreground: Color { get }
    
    /// Card title text.
    var cardForeground: Color { get }
    
    /// Card description text.
    var mutedForeground: Color { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 colour tokens for ``Auth0Theme``.
///
/// Defaults are sourced from Auth0's bundled **palette** — a 12-step
/// Neutral, Red, and Green scale (e.g. `Neutral/12`, `Red/3`) — so the
/// palette and the semantic mapping are kept in separate layers:
///
/// ```
/// Palette (XCAsset)         Semantic token           Usage
/// ─────────────────────     ─────────────────────    ─────────────────
/// Neutral/12 (dark text)  → primary                  CTA button fill
/// Neutral/3  (light fill) → onPrimary                Text on CTA button
/// Red/3      (light red)  → error                    Error container bg
/// Red/12     (deep red)   → onError                  Error text / icons
/// Green/3    (light green)→ success                  Success container bg
/// Green/12   (deep green) → onSuccess                Success text / icons
/// …
/// ```
///
/// Every palette entry is a **single adaptive colorset** — it contains
/// both a light-mode and a dark-mode swatch — so all semantic tokens
/// automatically flip when the user's appearance changes.
///
/// Pass values to the initialiser for any tokens you need to customise.
/// You can supply any `Color`, not just palette entries:
///
/// ```swift
/// // Override just the primary action colour
/// let colors = DefaultAuth0ColorTokens(
///     primary: .accentColor,
///     onPrimary: .white
/// )
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: colors))
/// ```
public struct DefaultAuth0ColorTokens: Auth0ColorTokens {

    // MARK: Primary

    public var primary: Color
    public var onPrimary: Color

    // MARK: Surfaces

    public var background: Color
    public var surface: Color
    public var onSurface: Color

    // MARK: Borders

    public var border: Color

    // MARK: Feedback — Error

    public var error: Color
    public var errorContainer: Color
    public var onError: Color

    // MARK: Feedback — Success

    public var success: Color
    public var successContainer: Color
    public var onSuccess: Color

    // MARK: Text

    public var textPrimary: Color
    public var textSecondary: Color
    
    // MARK: - Card
    public var foreground: Color
    public var cardForeground: Color
    public var mutedForeground: Color

    // MARK: Init

    /// Creates the default Auth0 colour tokens, each mapped to the
    /// appropriate step in the built-in Neutral, Red, or Green palette.
    ///
    /// Every parameter defaults to a palette entry (e.g. `Neutral/12`).
    /// Pass a value only for the tokens you need to override.
    ///
    /// - Parameters:
    ///   - primary: CTA button background. Default: `Neutral/12`.
    ///   - onPrimary: Text/icons on the primary surface. Default: `Neutral/3`.
    ///   - background: Main background colour. Default: `Neutral/1`.
    ///   - surface: Card and container surface. Default: `Neutral/1`.
    ///   - onSurface: Text/icons on surface. Default: `Neutral/11`.
    ///   - border: Input field and card borders. Default: `Neutral/6`.
    ///   - error: Error state container background. Default: `Red/3`.
    ///   - errorContainer: Subtle error banner background. Default: `Red/1`.
    ///   - onError: Text/icons on error surfaces. Default: `Red/12`.
    ///   - success: Success state container background. Default: `Green/3`.
    ///   - successContainer: Subtle success banner background. Default: `Green/1`.
    ///   - onSuccess: Text/icons on success surfaces. Default: `Green/12`.
    ///   - textPrimary: Main heading and body text. Default: `Neutral/12`.
    ///   - textSecondary: Secondary copy and captions. Default: `Neutral/11`.
    ///   - foreground: Card icon foreground. Default: `Neutral/12`.
    ///   - cardForeground:Card title text. Default: `Black`.
    ///   - mutedForeground: Card description text. Default: `Neutral/10`.
    public init(
        primary:          Color = Color("Neutral/12",  bundle: ResourceBundle.default),
        onPrimary:        Color = Color("Neutral/3",   bundle: ResourceBundle.default),
        background:       Color = Color("Neutral/1",   bundle: ResourceBundle.default),
        surface:          Color = Color("Neutral/1",   bundle: ResourceBundle.default),
        onSurface:        Color = Color("Neutral/11",  bundle: ResourceBundle.default),
        border:           Color = Color("Neutral/6",   bundle: ResourceBundle.default),
        error:            Color = Color("Red/3",       bundle: ResourceBundle.default),
        errorContainer:   Color = Color("Red/1",       bundle: ResourceBundle.default),
        onError:          Color = Color("Red/12",      bundle: ResourceBundle.default),
        success:          Color = Color("Green/3",     bundle: ResourceBundle.default),
        successContainer: Color = Color("Green/1",     bundle: ResourceBundle.default),
        onSuccess:        Color = Color("Green/12",    bundle: ResourceBundle.default),
        textPrimary:      Color = Color("Neutral/12",  bundle: ResourceBundle.default),
        textSecondary:    Color = Color("Neutral/11",  bundle: ResourceBundle.default),
        foreground:       Color = Color("Neutral/12",  bundle: ResourceBundle.default),
        cardForeground:   Color = Color.black,
        mutedForeground:  Color = Color("Neutral/10",  bundle: ResourceBundle.default),
    ) {
        self.primary          = primary
        self.onPrimary        = onPrimary
        self.background       = background
        self.surface          = surface
        self.onSurface        = onSurface
        self.border           = border
        self.error            = error
        self.errorContainer   = errorContainer
        self.onError          = onError
        self.success          = success
        self.successContainer = successContainer
        self.onSuccess        = onSuccess
        self.textPrimary      = textPrimary
        self.textSecondary    = textSecondary
        self.foreground       = foreground
        self.cardForeground   = cardForeground
        self.mutedForeground  = mutedForeground
    }
}
