import SwiftUI

public extension Color {
    /// A dynamic initializer that resolves based on the system color scheme.
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

// MARK: - Not making it public intentionally since on SDK import it might conflict with the client app's definition
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 1)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }
}

// MARK: - Extension to generate a dark theme counterpart for a given hex color
extension Color {
    /// Generates a dark theme counterpart for a given hex color.
    /// - Parameter hex: The 6-digit hex string (e.g., "3498db")
    /// - Returns: A Color adjusted for dark backgrounds.
    static func generateDarkCounterpart(from hex: String) -> Color {
        // 1. Convert hex to RGB components
        let scanner = Scanner(string: hex.trimmingCharacters(in: .whitespacesAndNewlines))
        if hex.hasPrefix("#") { scanner.currentIndex = hex.index(after: hex.startIndex) }
        
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgbValue & 0x0000FF) / 255.0
        
        // 2. Convert RGB to HSB (Hue, Saturation, Brightness)
        var h: CGFloat = 0, s: CGFloat = 0, b_val: CGFloat = 0, a: CGFloat = 0
        UIColor(red: r, green: g, blue: b, alpha: 1.0).getHue(&h, saturation: &s, brightness: &b_val, alpha: &a)
        
        // 3. Adjust for Dark Mode
        // Logic: Dark mode colors usually benefit from lower saturation (to avoid vibration)
        // and lower brightness (to blend with dark surfaces).
        let darkSaturation = s * 0.8  // Reduce saturation by 20%
        let darkBrightness = b_val * 0.7 // Reduce brightness by 30%
        
        return Color(hue: Double(h), saturation: Double(darkSaturation), brightness: Double(darkBrightness))
    }
}
