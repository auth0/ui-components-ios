import SwiftUI

struct TextModifier: ViewModifier {
    
    // MARK: - Properties
    @Environment(\.appTheme) var theme
    let role: TextRole
    let customTheme: (any Theme)? // Optional override

    // MARK: - Main body
    func body(content: Content) -> some View {
        // Use customTheme if provided, otherwise fallback to Environment
        let activeTheme = customTheme ?? theme
        
        content
            .font(font(for: activeTheme))
            .foregroundStyle(color(for: activeTheme))
            .tracking(role == .overline ? 1.2 : 0) // Overlines usually need more letter-spacing
            .textCase(role == .overline ? .uppercase : nil) // Automatic casing
    }

    // MARK: - Method to set the font as defined in the theme
    private func font(for theme: any Theme) -> Font {
        switch role {
        case .displayLarge:  return theme.typography.displayLarge
        case .displayMedium: return theme.typography.displayMedium
        case .display:       return theme.typography.display
        case .titleLarge:    return theme.typography.titleLarge
        case .title:         return theme.typography.title
        case .body:          return theme.typography.body
        case .bodySmall:     return theme.typography.bodySmall
        case .label:         return theme.typography.label
        case .helper:        return theme.typography.helper
        case .overline:      return theme.typography.overline
        }
    }

    // MARK: - Method to set the color as defined in the theme
    private func color(for theme: any Theme) -> Color {
        switch role {
        case .helper, .overline, .bodySmall:
            return theme.colors.textSecondary
        default:
            return theme.colors.textPrimary
        }
    }
}
