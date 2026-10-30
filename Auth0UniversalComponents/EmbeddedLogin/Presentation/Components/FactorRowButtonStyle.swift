import SwiftUI

/// A tappable row in a list of factors. Resting rows sit on an off-white card; a pressed row lifts to white with a
/// stronger border.
struct FactorRowButtonStyle: ButtonStyle {
    @Environment(\.auth0Theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: theme.radius.medium)
        return configuration.label
            .background(isPressed ? theme.colors.background.layerTop : theme.colors.background.layerMedium, in: shape)
            .overlay(shape.strokeBorder(isPressed ? theme.colors.border.bold : theme.colors.border.regular,
                                        lineWidth: 1))
            .shadow(color: .black.opacity(isPressed ? 0.08 : 0), radius: 6, x: 0, y: 2)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}
