import SwiftUI

struct AppThemeButtonStyle: ButtonStyle {
    // MARK: - Properties
    @Environment(\.theme) var theme
    var variant: ThemeButtonVariant = .primary
    let customTheme: (any Theme)? // Optional override
    
    func makeBody(configuration: Configuration) -> some View {
        // Use customTheme if provided, otherwise fallback to Environment
        let activeTheme = customTheme ?? theme
        
        configuration.label
            .font(activeTheme.typography.title) // Use semantic font
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(backgroundView(isPressed: configuration.isPressed, for: activeTheme))
            .foregroundColor(textColor(isPressed: configuration.isPressed, for: activeTheme))
            .cornerRadius(activeTheme.layout.cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
    
    // Logic to determine background based on variant
    @ViewBuilder
    private func backgroundView(isPressed: Bool, for activeTheme: Theme) -> some View {
        switch variant {
        case .primary:
            // TODO: (Sudhanshu) - Check this behaviour in practice
            Rectangle()
                .fill(
                    activeTheme.colors.primary
                        .opacity(isPressed ? 0.8 : 1.0))
        case .outline:
            Color.clear
                .overlay(
                    RoundedRectangle(cornerRadius: activeTheme.layout.cornerRadius)
                        .stroke(activeTheme.colors.border, lineWidth: activeTheme.layout.borderWidth)
                )
        case .ghost:
            Color.clear
        }
    }
    
    // Logic to determine text color
    private func textColor(isPressed: Bool, for activeTheme: Theme) -> Color {
        switch variant {
        case .primary: return activeTheme.colors.onPrimary
        case .outline, .ghost: return activeTheme.colors.textPrimary
        }
    }
}
