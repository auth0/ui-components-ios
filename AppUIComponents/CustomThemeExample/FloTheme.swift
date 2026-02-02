import SwiftUI
import Auth0UIComponents

// MARK: - Flo Theme Implementation
public struct FloTheme: Theme {
    public let colors: ColorTheme = FloColors()
    public let typography: TypographyTheme = FloTypography()
    public let layout: LayoutTheme = FloLayout()
    
    public init() {}
}

// MARK: - Colors
public struct FloColors: ColorTheme {
    // Brand & Surface
    // Flo's signature coral-pink
    public var primary: AnyShapeStyle { AnyShapeStyle(ThemeProvider.adaptiveColor(from: "FF8E9A")) }
    public var onPrimary: Color { .white }
    
    // Background is usually a very faint pink or white
    public var background: AnyShapeStyle { AnyShapeStyle(ThemeProvider.adaptiveColor(from: "FDF4F5")) }
    public var surface: AnyShapeStyle { AnyShapeStyle(Color.white) }
    public var onSurface: Color { ThemeProvider.adaptiveColor(from: "2D2D2D") }
    public var border: Color { ThemeProvider.adaptiveColor(from: "EAEAEA") }

    // Status
    public var error: Color { ThemeProvider.adaptiveColor(from: "FF4B55") }
    public var onError: Color { .white }
    public var success: Color { ThemeProvider.adaptiveColor(from: "48C9B0") } // Flo's soft teal/green
    public var successContainer: AnyShapeStyle { AnyShapeStyle(ThemeProvider.adaptiveColor(from: "E8F8F5")) }

    // Text Specific Roles
    public var textPrimary: Color { ThemeProvider.adaptiveColor(from: "2D2D2D") }
    public var textSecondary: Color { ThemeProvider.adaptiveColor(from: "8A8A8E") }
}

// MARK: - Typography
public struct FloTypography: TypographyTheme {
    // Flo uses SF Pro Rounded to maintain a soft, friendly medical feel
    
    public var displayLarge: Font { .system(size: 34, weight: .bold, design: .rounded) }
    public var displayMedium: Font { .system(size: 28, weight: .bold, design: .rounded) }
    public var display: Font { .system(size: 24, weight: .bold, design: .rounded) }
    
    public var titleLarge: Font { .system(size: 22, weight: .semibold, design: .rounded) }
    public var title: Font { .system(size: 18, weight: .semibold, design: .rounded) }
    
    public var body: Font { .system(size: 16, weight: .regular) }
    public var bodySmall: Font { .system(size: 14, weight: .regular) }
    
    public var label: Font { .system(size: 12, weight: .medium) }
    public var helper: Font { .system(size: 12, weight: .regular) }
    public var overline: Font { .system(size: 10, weight: .bold).uppercaseSmallCaps() }
}

// MARK: - Layout
public struct FloLayout: LayoutTheme {
    // Flo is known for its high corner radius (pill shapes)
    public var cornerRadius: CGFloat { 20.0 }
    public var borderWidth: CGFloat { 1.0 }
}
