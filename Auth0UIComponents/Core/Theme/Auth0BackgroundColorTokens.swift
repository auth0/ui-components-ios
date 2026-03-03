import SwiftUI

// MARK: - Protocol

/// A contract that defines all background colour tokens used by Auth0 UI Components.
///
/// Background tokens are divided into three sub-groups that mirror the Mobile Design System
/// dot-notation (`color.background.*`):
///
/// ```
/// Background
///   ├── Primary   primary · primarySubtle · inverse · accent
///   ├── Layers    layerTop · layerMedium · layerBase
///   └── Feedback  error · errorSubtle · success · successSubtle
/// ```
///
/// Conform to this protocol to supply custom background colours from your app's asset catalog:
///
/// ```swift
/// struct BrandBackground: Auth0BackgroundColorTokens {
///     var primary:       Color { Color("Background/Primary",       bundle: .main) }
///     var primarySubtle: Color { Color("Background/Primary",       bundle: .main).opacity(0.35) }
///     var inverse:       Color { Color("Background/Inverse",       bundle: .main) }
///     var accent:        Color { Color("Background/Accent",        bundle: .main) }
///     var layerTop:      Color { Color("Background/LayerTop",      bundle: .main) }
///     var layerMedium:   Color { Color("Background/LayerMedium",   bundle: .main) }
///     var layerBase:     Color { Color("Background/LayerBase",     bundle: .main) }
///     var error:         Color { Color("Background/Error",         bundle: .main) }
///     var errorSubtle:   Color { Color("Background/ErrorSubtle",   bundle: .main) }
///     var success:       Color { Color("Background/Success",       bundle: .main) }
///     var successSubtle: Color { Color("Background/SuccessSubtle", bundle: .main) }
/// }
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: DefaultAuth0ColorTokens(background: BrandBackground())))
/// ```
public protocol Auth0BackgroundColorTokens: Sendable {

    // MARK: - Primary

    /// Default background colour for CTA buttons and primary surfaces.
    /// Mobile Design System: `color.background.primary`
    var primary: Color { get }

    /// Softer variant of the primary background for low-emphasis areas.
    /// Mobile Design System: `color.background.primary.subtle`
    var primarySubtle: Color { get }

    /// Background that flips contrast, used against the primary background.
    /// Mobile Design System: `color.background.inverse`
    var inverse: Color { get }

    /// Background used to highlight branded or featured UI elements.
    /// Mobile Design System: `color.background.accent`
    var accent: Color { get }

    // MARK: - Layers

    /// Top-most layer background — overlays, modals, and popovers.
    /// Mobile Design System: `color.background.layer.top`
    var layerTop: Color { get }

    /// Mid-level layer background — cards and raised containers.
    /// Mobile Design System: `color.background.layer.medium`
    var layerMedium: Color { get }

    /// Foundational layer background — sits beneath all other layers.
    /// Mobile Design System: `color.background.layer.base`
    var layerBase: Color { get }

    // MARK: - Feedback

    /// Background for error states, alerts, and destructive messaging.
    /// Mobile Design System: `color.background.error`
    var error: Color { get }

    /// Muted error background for low-severity or inline error hints.
    /// Mobile Design System: `color.background.error.subtle`
    var errorSubtle: Color { get }

    /// Background for success states and positive confirmations.
    /// Mobile Design System: `color.background.success`
    var success: Color { get }

    /// Muted success background for subtle positive feedback.
    /// Mobile Design System: `color.background.success.subtle`
    var successSubtle: Color { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 background colour tokens.
///
/// Defaults are sourced from the `Background/` namespace in `Colors.xcassets`.
/// Every colorset is adaptive — it carries both a light-mode and a dark-mode swatch.
///
/// Pass values to the initialiser for any tokens you need to customise:
///
/// ```swift
/// let bg = DefaultAuth0BackgroundColorTokens(
///     primary: Color("Background/Primary", bundle: .main),
///     accent:  Color("Background/Accent",  bundle: .main)
/// )
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: DefaultAuth0ColorTokens(background: bg)))
/// ```
public struct DefaultAuth0BackgroundColorTokens: Auth0BackgroundColorTokens {

    // MARK: - Primary

    public var primary:       Color
    public var primarySubtle: Color
    public var inverse:       Color
    public var accent:        Color

    // MARK: - Layers

    public var layerTop:    Color
    public var layerMedium: Color
    public var layerBase:   Color

    // MARK: - Feedback

    public var error:         Color
    public var errorSubtle:   Color
    public var success:       Color
    public var successSubtle: Color

    // MARK: - Init

    public init(
        // Primary
        primary:       Color = Color("Background/Primary",       bundle: ResourceBundle.default),
        primarySubtle: Color = Color("Background/PrimarySubtle", bundle: ResourceBundle.default),
        inverse:       Color = Color("Background/Inverse",       bundle: ResourceBundle.default),
        accent:        Color = Color("Background/Accent",        bundle: ResourceBundle.default),
        // Layers
        layerTop:      Color = Color("Background/LayerTop",      bundle: ResourceBundle.default),
        layerMedium:   Color = Color("Background/LayerMedium",   bundle: ResourceBundle.default),
        layerBase:     Color = Color("Background/LayerBase",     bundle: ResourceBundle.default),
        // Feedback
        error:         Color = Color("Background/Error",         bundle: ResourceBundle.default),
        errorSubtle:   Color = Color("Background/ErrorSubtle",   bundle: ResourceBundle.default),
        success:       Color = Color("Background/Success",       bundle: ResourceBundle.default),
        successSubtle: Color = Color("Background/SuccessSubtle", bundle: ResourceBundle.default)
    ) {
        // Primary
        self.primary       = primary
        self.primarySubtle = primarySubtle
        self.inverse       = inverse
        self.accent        = accent
        // Layers
        self.layerTop      = layerTop
        self.layerMedium   = layerMedium
        self.layerBase     = layerBase
        // Feedback
        self.error         = error
        self.errorSubtle   = errorSubtle
        self.success       = success
        self.successSubtle = successSubtle
    }
}
