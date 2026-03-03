import SwiftUI

/// An informational view displayed when no authentication factors are configured.
///
/// This view shows a warning message to users indicating that they have not
/// configured any authentication factors on their account, which may be required
/// for security or access purposes.
struct EmptyFactorsView: View {

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        HStack {
            Image("info.circle.red", bundle: ResourceBundle.default)
                .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)

            Text("No factors configured")
                .foregroundStyle(theme.colors.text.onError)
                .auth0TextStyle(theme.typography.label)
            Spacer()
        }
        .padding(.all, theme.spacing.sm)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.button)
                .stroke(theme.colors.border.regular, lineWidth: 1)
        }
    }
}
