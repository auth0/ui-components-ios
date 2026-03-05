import CoreGraphics

// MARK: - Protocol

/// A contract that defines fixed component dimensions used by Auth0 UI Components.
///
/// Override this protocol to adjust component sizes — for example, to produce
/// larger touch targets on tvOS or an accessibility-first layout:
///
/// ```swift
/// struct LargeSizes: Auth0SizeTokens {
///     var buttonHeight: CGFloat { 56 }
///     var inputHeight: CGFloat { 68 }
///     var size2xlDimen: CGFloat { 52 }
///     var size3xlDimen: CGFloat { 60 }
///     var containerSizeLargeDimen: CGFloat { 56 }
///     var iconSmall: CGFloat { 20 }
///     var iconMedium: CGFloat { 28 }
///     var iconLarge: CGFloat { 32 }
/// }
/// ```
public protocol Auth0SizeTokens: Sendable {

    /// Height of all primary and secondary action buttons.
    var buttonHeight: CGFloat { get }

    /// Height of text and phone-number input fields.
    var inputHeight: CGFloat { get }

    /// 2XL dimension — width of a single character-input cell (OTP, PIN, or any digit-by-digit entry).
    var size2xlDimen: CGFloat { get }

    /// 3XL dimension — height of a single character-input cell (OTP, PIN, or any digit-by-digit entry).
    var size3xlDimen: CGFloat { get }

    /// Large container height — height of a read-only code display container (recovery codes, TOTP secrets, etc.).
    var containerSizeLargeDimen: CGFloat { get }

    /// Side length for small icons (chevrons, info indicators, checkmarks).
    var iconSmall: CGFloat { get }

    /// Side length for standard icons (authentication-method images).
    var iconMedium: CGFloat { get }

    /// Side length for large icons (three-dots menu button).
    var iconLarge: CGFloat { get }
}

// MARK: - Default Implementation

/// The built-in Auth0 component-size scale.
///
/// All tokens default to Auth0's standard dimensions.
/// Pass a value to the initialiser to override individual sizes.
public struct DefaultAuth0SizeTokens: Auth0SizeTokens {

    public var buttonHeight: CGFloat
    public var inputHeight: CGFloat
    public var size2xlDimen: CGFloat
    public var size3xlDimen: CGFloat
    public var containerSizeLargeDimen: CGFloat
    public var iconSmall: CGFloat
    public var iconMedium: CGFloat
    public var iconLarge: CGFloat

    /// Creates the default Auth0 size scale with optional per-token overrides.
    ///
    /// - Parameters:
    ///   - buttonHeight: Default `48`.
    ///   - inputHeight: Default `60`.
    ///   - size2xlDimen: Default `48`. Width of a single character-input cell.
    ///   - size3xlDimen: Default `56`. Height of a single character-input cell.
    ///   - containerSizeLargeDimen: Default `52`. Height of a read-only code display container.
    ///   - iconSmall: Default `16`.
    ///   - iconMedium: Default `24`.
    ///   - iconLarge: Default `28`.
    public init(
        buttonHeight: CGFloat = 48,
        inputHeight: CGFloat = 60,
        size2xlDimen: CGFloat = 48,
        size3xlDimen: CGFloat = 56,
        containerSizeLargeDimen: CGFloat = 52,
        iconSmall: CGFloat = 16,
        iconMedium: CGFloat = 24,
        iconLarge: CGFloat = 28
    ) {
        self.buttonHeight = buttonHeight
        self.inputHeight = inputHeight
        self.size2xlDimen = size2xlDimen
        self.size3xlDimen = size3xlDimen
        self.containerSizeLargeDimen = containerSizeLargeDimen
        self.iconSmall = iconSmall
        self.iconMedium = iconMedium
        self.iconLarge = iconLarge
    }
}
