import CoreGraphics

// MARK: - Protocol

/// A contract that defines corner-radius values used by Auth0 UI Components.
///
/// Override this protocol to produce a sharper or softer visual language:
///
/// ```swift
/// struct SharpRadius: Auth0RadiusTokens {
///     var small: CGFloat { 4 }
///     var medium: CGFloat { 6 }
///     var inputField: CGFloat { 8 }
///     var button: CGFloat { 8 }
///     var pill: CGFloat { 8 }   // square pill buttons
/// }
/// ```
public protocol Auth0RadiusTokens: Sendable {

    /// 8 pt — OTP digit-entry cells.
    var small: CGFloat { get }

    /// 12 pt — Passkey banner card and informational tiles.
    var medium: CGFloat { get }

    /// 14 pt — Text input fields and the recovery-code display container.
    var inputField: CGFloat { get }

    /// 16 pt — Primary CTA buttons and authenticator-method cards.
    var button: CGFloat { get }

    /// 24 pt — Fully rounded pill-style outline buttons ("Copy as Code", "Copy Code").
    var pill: CGFloat { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 corner-radius scale.
///
/// All tokens default to Auth0's standard values.
/// Pass a value to the initialiser to override individual radii.
public struct DefaultAuth0RadiusTokens: Auth0RadiusTokens {

    public var small: CGFloat
    public var medium: CGFloat
    public var inputField: CGFloat
    public var button: CGFloat
    public var pill: CGFloat

    /// Creates the default Auth0 corner-radius scale with optional per-token overrides.
    ///
    /// - Parameters:
    ///   - small: Default `8` — used for OTP digit cells.
    ///   - medium: Default `12` — used for banner cards.
    ///   - inputField: Default `14` — used for text inputs and code containers.
    ///   - button: Default `16` — used for CTA buttons and auth-method cards.
    ///   - pill: Default `24` — used for pill-shaped outline buttons.
    public init(
        small: CGFloat = 8,
        medium: CGFloat = 12,
        inputField: CGFloat = 14,
        button: CGFloat = 16,
        pill: CGFloat = 24
    ) {
        self.small = small
        self.medium = medium
        self.inputField = inputField
        self.button = button
        self.pill = pill
    }
}
