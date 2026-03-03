import SwiftUI

/// Displays a full-screen error state with a title, description, and action button.
///
/// Colours, typography, and sizing are all resolved from the active
/// ``Auth0Theme``, so the screen matches any custom theme injected with
/// ``SwiftUI/View/auth0Theme(_:)``.
struct ErrorScreen: View {

    @Environment(\.auth0Theme) private var theme

    /// The view model providing error copy and button callbacks.
    let viewModel: ErrorScreenViewModel

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: theme.spacing.md) {
                Text(viewModel.title)
                    .auth0TextStyle(theme.typography.displayMedium)
                    .foregroundStyle(theme.colors.text.bold)

                Text(viewModel.subTitle)
                    .onTapGesture {
                        viewModel.handleTextTap()
                    }

                Button {
                    viewModel.handleButtonClick()
                } label: {
                    Text(viewModel.buttonTitle)
                        .foregroundStyle(theme.colors.text.onPrimary)
                        .auth0TextStyle(theme.typography.label)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: theme.sizes.buttonHeight)
                .background(theme.colors.background.primary)
                .cornerRadius(theme.radius.button)
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.button)
                        .stroke(theme.colors.background.primary, lineWidth: 2)
                )
            }
            Spacer()
        }.padding()
    }
}
