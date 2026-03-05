import CoreGraphics

// MARK: - Protocol

/// A contract that defines the spacing scale used by Auth0 UI Components.
///
/// The default scale follows a 4 pt grid. If your design system
/// uses a different base unit, implement this protocol:
///
/// ```swift
/// struct PointSpacing: Auth0SpacingTokens {
///     var xxs:  CGFloat { 4 }
///     var xs:   CGFloat { 8 }
///     var sm:   CGFloat { 12 }
///     var md:   CGFloat { 16 }
///     var lg:   CGFloat { 24 }
///     var xl:   CGFloat { 32 }
///     var xxl:  CGFloat { 48 }
///     var xxxl: CGFloat { 56 }
/// }
/// ```
public protocol Auth0SpacingTokens: Sendable {

    /// 4 pt — Minimal gap between tightly coupled elements.
    var xxs: CGFloat { get }

    /// 8 pt — Small gap between grouped elements.
    var xs: CGFloat { get }

    /// 12 pt — Medium internal padding.
    var sm: CGFloat { get }

    /// 16 pt — Standard component and container padding.
    var md: CGFloat { get }

    /// 24 pt — Larger padding for major sections.
    var lg: CGFloat { get }

    /// 32 pt — Extra-large padding.
    var xl: CGFloat { get }

    /// 48 pt — Double-extra-large padding.
    var xxl: CGFloat { get }

    /// 56 pt — Triple-extra-large padding.
    var xxxl: CGFloat { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 spacing scale based on a 4 pt grid.
///
/// All tokens default to their standard values.
/// Pass a value to the initialiser to override individual steps.
public struct DefaultAuth0SpacingTokens: Auth0SpacingTokens {

    public var xxs: CGFloat
    public var xs: CGFloat
    public var sm: CGFloat
    public var md: CGFloat
    public var lg: CGFloat
    public var xl: CGFloat
    public var xxl: CGFloat
    public var xxxl: CGFloat

    /// Creates the default Auth0 spacing scale with optional per-token overrides.
    ///
    /// - Parameters:
    ///   - xxs:  Default `4`.
    ///   - xs:   Default `8`.
    ///   - sm:   Default `12`.
    ///   - md:   Default `16`.
    ///   - lg:   Default `24`.
    ///   - xl:   Default `32`.
    ///   - xxl:  Default `48`.
    ///   - xxxl: Default `56`.
    public init(
        xxs: CGFloat = 4,
        xs: CGFloat = 8,
        sm: CGFloat = 12,
        md: CGFloat = 16,
        lg: CGFloat = 24,
        xl: CGFloat = 32,
        xxl: CGFloat = 48,
        xxxl: CGFloat = 56
    ) {
        self.xxs  = xxs
        self.xs   = xs
        self.sm   = sm
        self.md   = md
        self.lg   = lg
        self.xl   = xl
        self.xxl  = xxl
        self.xxxl = xxxl
    }
}
