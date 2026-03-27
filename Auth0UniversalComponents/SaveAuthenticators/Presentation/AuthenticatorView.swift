import SwiftUI
import Auth0

/// A single row displaying a saved authenticator with a contextual delete action.
///
/// Manages its own confirmation-dialog state so that tapping the three-dot menu
/// on one row never accidentally triggers the dialog on a different row.
struct AuthenticatorView: View {

    // MARK: - Theme
    @Environment(\.auth0Theme) private var theme

    // MARK: - Properties
    let type: AuthMethodType
    let authenticationMethod: AuthenticationMethod
    let onDelete: () async -> Void

    // MARK: - State properties
    @State private var showConfirmationDialog = false

    // MARK: - Main Body
    var body: some View {
        HStack {

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(authenticationMethod.name ?? type.savedAuthenticatorsCellTitle)
                    .auth0TextStyle(theme.typography.label)
                    .foregroundStyle(theme.colors.text.bold)

                Text("Created on \(authenticationMethod.formatIsoDate)")
                    .auth0TextStyle(theme.typography.helper)
                    .foregroundStyle(theme.colors.text.regular)
            }

            Spacer()

            Image("threedots", bundle: ResourceBundle.default)
                .frame(width: theme.sizes.iconLarge, height: theme.sizes.iconLarge)
                .onTapGesture {
                    showConfirmationDialog = true
                }
        }
        .padding(theme.spacing.lg)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.button)
                .strokeBorder(theme.colors.border.regular, lineWidth: 1)
        }
        .background(theme.colors.background.layerMedium)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.button))
        .confirmationDialog(type.confirmationDialogTitle,
                            isPresented: $showConfirmationDialog,
                            titleVisibility: .visible) {
            Button(type.confirmationDialogDestructiveButtonTitle,
                   role: .destructive) {
                Task {
                    await onDelete()
                }
            }
        }
    }
}
