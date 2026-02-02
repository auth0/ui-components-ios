import SwiftUI

public struct DefaultColorTheme: ColorTheme {
    
    // MARK: - Core Semantic Colors
    public var primary: AnyShapeStyle {
        AnyShapeStyle(ThemeProvider.adaptiveColor(from: "262420"))
    }
    public var onPrimary: Color { .white }
    
    public var background: AnyShapeStyle {
        AnyShapeStyle(Color(light: .white, dark: Color(white: 0.05)))
    }
    
    public var surface: AnyShapeStyle {
        AnyShapeStyle(Color(light: Color(white: 0.97), dark: Color(white: 0.12)))
    }
    
    public var onSurface: Color {
        Color(light: .black, dark: .white)
    }
    
    public var border: Color {
        Color(light: Color(white: 0.9), dark: Color(white: 0.25))
    }
    
    // MARK: - Status Colors
    public var error: Color { .red }
    public var onError: Color { .white }
    public var success: Color { .green }
    public var successContainer: AnyShapeStyle {
        AnyShapeStyle(Color(light: .green.opacity(0.12), dark: .green.opacity(0.25)))
    }
    
    // MARK: - Text Roles
    public var textPrimary: Color { Color(light: .black, dark: .white) }
    public var textSecondary: Color { .secondary } // System adaptive
    
    // MARK: - Public Init
    public init() {}
}

public struct DefaultLayoutTheme: LayoutTheme {

    // MARK: - Layout
    public var cornerRadius: CGFloat { 16 }
    public var borderWidth: CGFloat { 1 }
    
    // MARK: - Public Init
    public init() {}
}

public struct DefaultTypographyTheme: TypographyTheme {
    
    // MARK: - Typography (Scale-Aware)
    // Using system styles ensures Dynamic Type support (accessibility)
    
    public var displayLarge: Font  { .system(size: 34, weight: .semibold, design: .rounded) }
    public var displayMedium: Font { .system(size: 28, weight: .semibold, design: .rounded) }
    public var display: Font  { .system(size: 22, weight: .semibold) }
    
    public var titleLarge: Font    { .system(size: 20, weight: .semibold) }
    public var title: Font   { .system(size: 17, weight: .semibold) }
    
    public var body: Font     { .system(size: 17, weight: .regular) }
    public var bodySmall: Font     { .system(size: 15, weight: .regular) }
    
    public var label: Font         { .system(size: 16, weight: .medium) }
    public var helper: Font        { .system(size: 13, weight: .regular) }
    public var overline: Font      { .system(size: 11, weight: .regular) }
    
    // MARK: - Public Init
    public init() {}
}

public struct DefaultTheme: Theme {
    
    public var colors: ColorTheme {
        return DefaultColorTheme()
    }
    
    public var typography: TypographyTheme {
        return DefaultTypographyTheme()
    }
    
    public var layout: LayoutTheme {
        return DefaultLayoutTheme()
    }
    
    // MARK: - Public Init
    public init() {}
    
}
