import CoreGraphics

// MARK: - Protocol

/// A contract that defines the spacing scale used by Auth0 UI Components.
///
/// The default scale follows a 4 pt grid.  If your design system
/// uses a different base unit, implement this protocol:
///
/// ```swift
/// struct EightPointSpacing: Auth0SpacingTokens {
///     var xs: CGFloat { 8 }
///     var sm: CGFloat { 16 }
///     var md: CGFloat { 24 }
///     var base: CGFloat { 32 }
///     var lg: CGFloat { 40 }
///     var xl: CGFloat { 48 }
///     var `2xl`: CGFloat { 56 }
///     var `3xl`: CGFloat { 64 }
///     var `4xl`: CGFloat { 72 }
///     var `5xl`: CGFloat { 80 }
/// }
/// ```
public protocol Auth0SpacingTokens: Sendable {

    /// 4 pt — Minimal gap between tightly coupled elements.
    var xs: CGFloat { get }

    /// 8 pt — Small gap between grouped elements.
    var sm: CGFloat { get }

    /// 12 pt — Medium internal padding.
    var md: CGFloat { get }

    /// 16 pt — Standard component and container padding.
    var base: CGFloat { get }

    /// 20 pt — Larger padding for major sections.
    var lg: CGFloat { get }

    /// 24 pt — Extra-large padding.
    var xl: CGFloat { get }

    /// 32 pt — Double-extra-large padding.
    var `2xl`: CGFloat { get }

    /// 40 pt — Triple-extra-large padding.
    var `3xl`: CGFloat { get }

    /// 48 pt — Quadruple-extra-large padding.
    var `4xl`: CGFloat { get }

    /// 56 pt — Quintuple-extra-large padding.
    var `5xl`: CGFloat { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 spacing scale based on a 4 pt grid.
///
/// All tokens default to their standard values.
/// Pass a value to the initialiser to override individual steps.
public struct DefaultAuth0SpacingTokens: Auth0SpacingTokens {

    public var xs: CGFloat
    public var sm: CGFloat
    public var md: CGFloat
    public var base: CGFloat
    public var lg: CGFloat
    public var xl: CGFloat
    public var `2xl`: CGFloat
    public var `3xl`: CGFloat
    public var `4xl`: CGFloat
    public var `5xl`: CGFloat

    /// Creates the default Auth0 spacing scale with optional per-token overrides.
    ///
    /// - Parameters:
    ///   - xs:   Default `4`.
    ///   - sm:   Default `8`.
    ///   - md:   Default `12`.
    ///   - base: Default `16`.
    ///   - lg:   Default `20`.
    ///   - xl:   Default `24`.
    ///   - 2xl:  Default `32`.
    ///   - 3xl:  Default `40`.
    ///   - 4xl:  Default `48`.
    ///   - 5xl:  Default `56`.
    public init(
        xs: CGFloat = 4,
        sm: CGFloat = 8,
        md: CGFloat = 12,
        base: CGFloat = 16,
        lg: CGFloat = 20,
        xl: CGFloat = 24,
        `2xl`: CGFloat = 32,
        `3xl`: CGFloat = 40,
        `4xl`: CGFloat = 48,
        `5xl`: CGFloat = 56
    ) {
        self.xs    = xs
        self.sm    = sm
        self.md    = md
        self.base  = base
        self.lg    = lg
        self.xl    = xl
        self.`2xl` = `2xl`
        self.`3xl` = `3xl`
        self.`4xl` = `4xl`
        self.`5xl` = `5xl`
    }
}
