import SwiftUI
import Auth0UIComponents

// MARK: - GrandVision Theme Implementation
public struct GrandVisionTheme: Theme {
    public let colors: ColorTheme = GrandVisionColors()
    public let typography: TypographyTheme = GrandVisionTypography()
    public let layout: LayoutTheme = GrandVisionLayout()
    
    public init() {}
}

// MARK: - Colors
public struct GrandVisionColors: ColorTheme {
    // Brand & Surface
    // GrandVision Navy: Professional and Trustworthy
    public var primary: AnyShapeStyle { AnyShapeStyle(ThemeProvider.adaptiveColor(from: "004899")) }
    public var onPrimary: Color { .white }
    
    // GrandVision Yellow is often used for CTAs/Highlights, but background remains clean
    public var background: AnyShapeStyle { AnyShapeStyle(ThemeProvider.adaptiveColor(from: "F4F7F9")) }
    public var surface: AnyShapeStyle { AnyShapeStyle(Color.white) }
    public var onSurface: Color { ThemeProvider.adaptiveColor(from: "1A1A1A") }
    public var border: Color { ThemeProvider.adaptiveColor(from: "D1DCE5") }

    // Status
    public var error: Color { ThemeProvider.adaptiveColor(from: "E30613") } // Standard retail red
    public var onError: Color { .white }
    public var success: Color { ThemeProvider.adaptiveColor(from: "008542") } // Medical/Optical green
    public var successContainer: AnyShapeStyle { AnyShapeStyle(ThemeProvider.adaptiveColor(from: "E6F3EC")) }

    // Text Specific Roles
    // Using a deep charcoal for better readability than pure black
    public var textPrimary: Color { ThemeProvider.adaptiveColor(from: "1A1A1A") }
    public var textSecondary: Color { ThemeProvider.adaptiveColor(from: "58666E") }
    
    // Branding Highlight (The Yellow)
    public var accent: Color { ThemeProvider.adaptiveColor(from: "FFD100") }
}

// MARK: - Typography
public struct GrandVisionTypography: TypographyTheme {
    // GrandVision uses "GrandVision Sans" or "Montserrat".
    // In SwiftUI, we use the standard system font with specific weighting.
    
    public var displayLarge: Font { .system(size: 32, weight: .bold) }
    public var displayMedium: Font { .system(size: 26, weight: .bold) }
    public var display: Font { .system(size: 22, weight: .bold) }
    
    public var titleLarge: Font { .system(size: 20, weight: .semibold) }
    public var title: Font { .system(size: 18, weight: .semibold) }
    
    public var body: Font { .system(size: 16, weight: .regular) }
    public var bodySmall: Font { .system(size: 14, weight: .regular) }
    
    public var label: Font { .system(size: 13, weight: .bold) }
    public var helper: Font { .system(size: 12, weight: .regular) }
    public var overline: Font { .system(size: 11, weight: .black).uppercaseSmallCaps() }
}

// MARK: - Layout
public struct GrandVisionLayout: LayoutTheme {
    // GrandVision uses a more "Standard Retail" rounding.
    // Crisp corners with slight rounding for buttons/cards.
    public var cornerRadius: CGFloat { 4.0 }
    public var borderWidth: CGFloat { 1.0 }
}
