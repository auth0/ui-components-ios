import SwiftUI

// MARK: - Theme Container

/// The central theme configuration for Auth0 UI Components.
///
/// `Auth0Theme` composes all five token categories — colours, typography,
/// spacing, corner radii, and component sizes — into a single injectable value.
/// Inject it into your view hierarchy using the ``SwiftUI/View/auth0Theme(_:)``
/// modifier.  All Auth0 UI Components views will automatically read the theme
/// from the SwiftUI environment.
///
/// ## Zero configuration
///
/// Auth0 UI Components work out of the box without any theme setup:
///
/// ```swift
/// struct ContentView: View {
///     var body: some View {
///         MyAccountAuthMethodsView()   // uses Auth0's default palette
///     }
/// }
/// ```
///
/// ## Partial colour override
///
/// Pass a custom `Default*` sub-struct for any colour category to change only
/// the tokens you care about; all others stay as the Auth0 defaults:
///
/// ```swift
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(
///         colors: DefaultAuth0ColorTokens(
///             background: DefaultAuth0BackgroundColorTokens(primary: Brand.primary),
///             text: DefaultAuth0TextColorTokens(onPrimary: .white)
///         )
///     ))
/// ```
///
/// ## Full category override
///
/// Implement the three category protocols for complete control:
///
/// ```swift
/// struct BrandColors: Auth0ColorTokens {
///     var background: any Auth0BackgroundColorTokens { BrandBackground() }
///     var text: any Auth0TextColorTokens { BrandText() }
///     var border: any Auth0BorderColorTokens { BrandBorder() }
/// }
///
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: BrandColors()))
/// ```
///
/// ## In-place mutation
///
/// Because `Auth0Theme` is a struct with `var` properties, you can mutate a
/// copy of the default before injecting it:
///
/// ```swift
/// var theme = Auth0Theme()
/// theme.colors = BrandColors()
/// theme.typography = DefaultAuth0TypographyTokens(
///     body: Auth0TextStyle(font: .custom("Lato-Regular", size: 17), tracking: 0, lineSpacing: 7)
/// )
/// MyAccountAuthMethodsView().auth0Theme(theme)
/// ```
///
/// ## Accessing the theme in custom views
///
/// If you extend Auth0 UI Components with your own views, read the active theme
/// via `@Environment`:
///
/// ```swift
/// struct MyCustomBanner: View {
///     @Environment(\.auth0Theme) private var theme
///
///     var body: some View {
///         Text("Hello")
///             .auth0TextStyle(theme.typography.body)
///             .foregroundStyle(theme.colors.text.bold)
///             .padding(theme.spacing.base)
///     }
/// }
/// ```
public struct Auth0Theme {

    /// All colour tokens for this theme.
    public var colors: any Auth0ColorTokens

    /// All typography tokens for this theme.
    public var typography: any Auth0TypographyTokens

    /// All spacing tokens for this theme.
    public var spacing: any Auth0SpacingTokens

    /// All corner-radius tokens for this theme.
    public var radius: any Auth0RadiusTokens

    /// All fixed component-size tokens for this theme.
    public var sizes: any Auth0SizeTokens

    /// Creates an `Auth0Theme` with optional per-category overrides.
    ///
    /// Every category defaults to its corresponding `Default*` implementation
    /// so passing no arguments produces the full Auth0 brand look.
    ///
    /// - Parameters:
    ///   - colors: Colour tokens. Defaults to ``DefaultAuth0ColorTokens``.
    ///   - typography: Typography tokens. Defaults to ``DefaultAuth0TypographyTokens``.
    ///   - spacing: Spacing tokens. Defaults to ``DefaultAuth0SpacingTokens``.
    ///   - radius: Corner-radius tokens. Defaults to ``DefaultAuth0RadiusTokens``.
    ///   - sizes: Component-size tokens. Defaults to ``DefaultAuth0SizeTokens``.
    public init(
        colors: any Auth0ColorTokens = DefaultAuth0ColorTokens(),
        typography: any Auth0TypographyTokens = DefaultAuth0TypographyTokens(),
        spacing: any Auth0SpacingTokens = DefaultAuth0SpacingTokens(),
        radius: any Auth0RadiusTokens = DefaultAuth0RadiusTokens(),
        sizes: any Auth0SizeTokens = DefaultAuth0SizeTokens()
    ) {
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.radius = radius
        self.sizes = sizes
    }
}

// MARK: - SwiftUI Environment

private struct Auth0ThemeKey: EnvironmentKey {
    /// Default theme used when ``SwiftUI/View/auth0Theme(_:)`` is not called.
    static let defaultValue = Auth0Theme()
}

extension EnvironmentValues {
    /// The active ``Auth0Theme`` in this view's environment.
    ///
    /// Set this value using the ``SwiftUI/View/auth0Theme(_:)`` view modifier
    /// rather than writing to `EnvironmentValues` directly.
    public var auth0Theme: Auth0Theme {
        get { self[Auth0ThemeKey.self] }
        set { self[Auth0ThemeKey.self] = newValue }
    }
}

extension View {
    /// Injects an ``Auth0Theme`` into the view hierarchy.
    ///
    /// All Auth0 UI Components views that are descendants of the modified view
    /// will use the supplied theme.  If this modifier is not applied, the
    /// default Auth0 theme is used automatically.
    ///
    /// ```swift
    /// MyAccountAuthMethodsView()
    ///     .auth0Theme(Auth0Theme(
    ///         colors: DefaultAuth0ColorTokens(backgroundPrimary: Brand.primary)
    ///     ))
    /// ```
    ///
    /// - Parameter theme: The theme to propagate to all descendant views.
    /// - Returns: A view that injects `theme` into its SwiftUI environment.
    public func auth0Theme(_ theme: Auth0Theme) -> some View {
        environment(\.auth0Theme, theme)
    }
}
