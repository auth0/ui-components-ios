import SwiftUI
import Auth0

/// Displays a single authentication method as a selectable card.
///
/// This view shows one authentication method (email, SMS, TOTP, push, passkeys, or recovery codes)
/// with an icon, title, and enrollment status indicator. It is tappable to navigate to the
/// management or enrollment screen for that authentication method.
struct MyAccountAuthMethodView: View {

    @Environment(\.auth0Theme) private var theme
    /// SDK router injected by `MyAccountAuthMethodsView` via environmentObject.
    @EnvironmentObject private var router: Router<Route>
    /// View model providing authentication method details and actions
    @StateObject var viewModel: MyAccountAuthMethodViewModel

    init(viewModel: MyAccountAuthMethodViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HStack {
            Image(viewModel.image(), bundle: ResourceBundle.default)
                .renderingMode(.template)
                .foregroundStyle(theme.colors.background.primary)
                .frame(width: theme.sizes.iconMedium, height: theme.sizes.iconMedium)
                .padding(.trailing, theme.spacing.md)

            Text(viewModel.title())
                .auth0TextStyle(theme.typography.label)
                .foregroundStyle(theme.colors.text.bold)
                .padding(.trailing, theme.spacing.md)

            Spacer()

            if viewModel.isAtleastOnceAuthFactorEnrolled() {
                Image("checkmark.green", bundle: ResourceBundle.default)
                    .frame(width: theme.sizes.iconMedium, height: theme.sizes.iconMedium)
                    .padding(.trailing, theme.spacing.md)
            }

            Image("chevron", bundle: ResourceBundle.default)
                .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
        }
        .contentShape(Rectangle())
        .padding(.all, theme.spacing.lg)
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.button)
                .stroke(theme.colors.border.regular, lineWidth: 1)
        }
        .onTapGesture {
            router.navigate(to: viewModel.navigationRoute())
        }
    }
}
