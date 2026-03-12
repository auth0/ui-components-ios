import SwiftUI
import Auth0UniversalComponents

struct RadioButtonView: View {

    // MARK: - Properties
    let isSelected: Bool

    // MARK: - Theme
    @Environment(\.auth0Theme) private var theme

    // MARK: - Body
    var body: some View {
        Circle()
            .fill(isSelected ? theme.colors.background.accent : theme.colors.background.layerBase)
            .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
            .overlay {
                Circle()
                    .strokeBorder(theme.colors.border.regular, lineWidth: 2)

                Circle()
                    .fill(isSelected ? theme.colors.background.layerMedium : theme.colors.background.layerBase)
                    .frame(width: 6, height: 6)
            }
    }
}
