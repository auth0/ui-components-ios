import SwiftUI

public protocol TypographyTheme {
    // Display (Large & Impactful)
    var displayLarge: Font { get }
    var displayMedium: Font { get }
    var display: Font { get }
    
    // Titles (Headings)
    var titleLarge: Font { get }
    var title: Font { get }
    
    // Content
    var body: Font { get }
    var bodySmall: Font { get }
    
    // Utilities
    var label: Font { get }
    var helper: Font { get }
    var overline: Font { get }
}

public enum TextRole {
    case displayLarge, displayMedium, display
    case titleLarge, title
    case body, bodySmall
    case label
    case helper
    case overline
}
