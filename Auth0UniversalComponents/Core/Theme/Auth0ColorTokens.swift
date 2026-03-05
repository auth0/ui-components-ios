import SwiftUI

// MARK: - Protocol

/// A contract that aggregates the three colour-token namespaces used by Auth0 UI Components.
///
/// The SDK uses a three-layer colour system:
///
/// 1. **Palette** — `Colors.xcassets` contains Mobile Design System colour tokens organised into
///    three namespaces: `Background/`, `Border/`, and `Text/`. Each entry is an
///    adaptive colorset with light and dark swatches baked in.
/// 2. **Category tokens** — ``Auth0BackgroundColorTokens``, ``Auth0BorderColorTokens``,
///    and ``Auth0TextColorTokens`` map roles onto palette entries within each namespace.
/// 3. **Container** — This protocol aggregates the three category-token sets into a
///    single injectable value consumed via ``Auth0Theme``.
///
/// Access tokens through the three namespaced properties:
///
/// ```swift
/// theme.colors.background.primary    // CTA button fill
/// theme.colors.text.bold             // Primary headings
/// theme.colors.border.regular        // Input field stroke
/// ```
///
/// ``DefaultAuth0ColorTokens`` composes the three `Default*` implementations.
/// Its init exposes each category so you can override one without touching the others:
///
/// ```swift
/// let colors = DefaultAuth0ColorTokens(
///     background: DefaultAuth0BackgroundColorTokens(primary: Brand.primary),
///     text: DefaultAuth0TextColorTokens(onPrimary: Brand.onPrimary)
/// )
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: colors))
/// ```
///
/// For full control, implement the protocol and supply all three category token sets:
///
/// ```swift
/// struct BrandColors: Auth0ColorTokens {
///     var background: any Auth0BackgroundColorTokens { BrandBackground() }
///     var text: any Auth0TextColorTokens { BrandText() }
///     var border: any Auth0BorderColorTokens { BrandBorder() }
/// }
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: BrandColors()))
/// ```
public protocol Auth0ColorTokens: Sendable {

    /// All background colour tokens — fills for surfaces, layers, and feedback states.
    var background: any Auth0BackgroundColorTokens { get }

    /// All text colour tokens — content text and on-colour text.
    var text: any Auth0TextColorTokens { get }

    /// All border colour tokens — strokes, dividers, and elevation shadows.
    var border: any Auth0BorderColorTokens { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 colour tokens for ``Auth0Theme``.
///
/// Composes the three default category implementations:
/// ``DefaultAuth0BackgroundColorTokens``, ``DefaultAuth0TextColorTokens``, and
/// ``DefaultAuth0BorderColorTokens``. All palette entries are sourced from
/// `Colors.xcassets` and are adaptive (light + dark mode).
///
/// Override a single category without touching the others:
///
/// ```swift
/// // Override only the primary action colour
/// let colors = DefaultAuth0ColorTokens(
///     background: DefaultAuth0BackgroundColorTokens(primary: .accentColor),
///     text: DefaultAuth0TextColorTokens(onPrimary: .white)
/// )
/// MyAccountAuthMethodsView()
///     .auth0Theme(Auth0Theme(colors: colors))
/// ```
public struct DefaultAuth0ColorTokens: Auth0ColorTokens {

    public var background: any Auth0BackgroundColorTokens
    public var text: any Auth0TextColorTokens
    public var border: any Auth0BorderColorTokens

    // MARK: - Init

    /// Creates the default Auth0 colour tokens by composing the three category defaults.
    ///
    /// Pass a custom implementation for any category you need to override.
    /// All others keep the built-in Auth0 values.
    ///
    /// - Parameters:
    ///   - background: Background colour tokens. Defaults to ``DefaultAuth0BackgroundColorTokens``.
    ///   - text: Text colour tokens. Defaults to ``DefaultAuth0TextColorTokens``.
    ///   - border: Border colour tokens. Defaults to ``DefaultAuth0BorderColorTokens``.
    public init(
        background: any Auth0BackgroundColorTokens = DefaultAuth0BackgroundColorTokens(),
        text: any Auth0TextColorTokens       = DefaultAuth0TextColorTokens(),
        border: any Auth0BorderColorTokens     = DefaultAuth0BorderColorTokens()
    ) {
        self.background = background
        self.text       = text
        self.border     = border
    }
}
