import SwiftUI

public struct ThemeProvider {
    public static func adaptiveColor(from hex: String) -> Color {
        let lightColor = Color(hex: hex) // Standard hex initializer
        let darkColor = Color.generateDarkCounterpart(from: hex)
        
        return Color(UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark ? UIColor(darkColor) : UIColor(lightColor)
        })
    }
}
