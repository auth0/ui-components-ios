import SwiftUI

public protocol ColorTheme {
    // Brand & Surface
    var primary: AnyShapeStyle { get }
    var onPrimary: Color { get }
    var background: AnyShapeStyle { get }
    var surface: AnyShapeStyle { get }
    var onSurface: Color { get }
    var border: Color { get }

    // Status
    var error: Color { get }
    var onError: Color { get }
    var success: Color { get }
    var successContainer: AnyShapeStyle { get }

    // Text Specific Roles
    var textPrimary: Color { get }
    var textSecondary: Color { get }
}
