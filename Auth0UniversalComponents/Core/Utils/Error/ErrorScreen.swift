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
        ZStack(alignment: .topLeading) {
            VStack {
                Spacer()
                VStack(spacing: theme.spacing.sm) {
                    Text(viewModel.title)
                        .multilineTextAlignment(.center)
                        .auth0TextStyle(theme.typography.displayMedium)
                        .foregroundStyle(theme.colors.text.bold)

                    Text(viewModel.subTitle)
                        .auth0TextStyle(theme.typography.label)
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

            if viewModel.onDismiss != nil {
                Button {
                    viewModel.handleDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.colors.text.bold)
                        .frame(width: 30, height: 30)
                        .background(theme.colors.background.layerTop)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                }
                .padding(theme.spacing.md)
            }
        }
        .background(theme.colors.background.layerBase.ignoresSafeArea())
    }
}
