import SwiftUI

/// Full-screen view for passkey enrollment.
///
/// Guides users through the complete passkey enrollment process, including
/// educational content about passkeys, the platform credential provider integration,
/// and confirmation of enrollment.
///
/// Availability: Requires iOS 16.6, macOS 13.5, or visionOS 1.0+
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct PasskeysEnrollmentView: View {

    @Environment(\.auth0Theme) private var theme
    /// View model handling passkey enrollment state and logic
    @StateObject private var viewModel: PasskeysEnrollmentViewModel

    /// Initializes the passkey enrollment view.
    ///
    /// - Parameter viewModel: The view model managing passkey enrollment state and logic
    init(viewModel: PasskeysEnrollmentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            if viewModel.showLoader {
                Auth0Loader()
            } else if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack {
                        Image("Shape", bundle: ResourceBundle.default)
                            .frame(width: 165, height: 165)
                            .padding(.top, theme.spacing.xxxl)
                            .padding(.bottom, theme.spacing.xxl)

                        Text("Enable Passkey")
                            .auth0TextStyle(theme.typography.displayMedium)
                            .foregroundStyle(theme.colors.text.bold)
                            .padding(.bottom, theme.spacing.lg)

                        HStack {
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("• What are passkeys?")
                                        .auth0TextStyle(theme.typography.title)
                                        .foregroundStyle(theme.colors.text.bold)
                                        .padding(.bottom, theme.spacing.xxs)
                                }
                                .padding(.leading, theme.spacing.xxs)

                                Text("Passkeys are encrypted digital keys you create using your fingerprint, face, or screen lock.")
                                    .multilineTextAlignment(.leading)
                                    .auth0TextStyle(theme.typography.body)
                                    .foregroundStyle(theme.colors.text.regular)
                                    .padding(.bottom, 30)

                                Text("• Where are passkeys saved?")
                                    .auth0TextStyle(theme.typography.title)
                                    .foregroundStyle(theme.colors.text.bold)
                                    .padding(.bottom, theme.spacing.xxs)
                                    .padding(.leading, theme.spacing.xxs)

                                Text("Passkeys are saved in your credential manager, so you can sign in on other devices.")
                                    .auth0TextStyle(theme.typography.body)
                                    .foregroundStyle(theme.colors.text.regular)
                                    .padding(.bottom, 30)
                            }
                        }

                        Button {
                            Task {
                                await viewModel.startEnrollment()
                            }
                        } label: {
                            Label {
                                Text("Create a Passkey")
                                    .auth0TextStyle(theme.typography.label)
                                    .foregroundStyle(theme.colors.text.onPrimary)
                                    .padding(.vertical, 10)
                            } icon: {
                                Image("passkey", bundle: ResourceBundle.default)
                                    .resizable()
                                    .renderingMode(.template)
                                    .foregroundColor(theme.colors.text.onPrimary)
                                    .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
                            }.frame(maxWidth: .infinity)
                        }
                        .frame(height: theme.sizes.buttonHeight)
                        .background(
                            LinearGradient(
                                stops: [
                                    Gradient.Stop(color: Color.white.opacity(0.15), location: 0.00),
                                    Gradient.Stop(color: Color.white.opacity(0.00), location: 1.00)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .background(theme.colors.background.primary)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.button))
                        .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 1)
                        .padding(.top, theme.spacing.xxl)

                        Text("Skip")
                            .auth0TextStyle(theme.typography.label)
                            .foregroundStyle(theme.colors.text.bold)
                            .onTapGesture {
                                NavigationStore.shared.pop()
                            }
                            .padding(.top, theme.spacing.lg)
                    }
                }
            }
        }
        .padding(theme.spacing.xl)
        .padding(.top, theme.spacing.xxl)
        .background(theme.colors.background.layerBase)
        .ignoresSafeArea()
    }
}
