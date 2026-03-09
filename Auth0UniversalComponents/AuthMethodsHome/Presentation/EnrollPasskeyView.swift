import SwiftUI

/// A promotional banner view for passkey enrollment.
///
/// This view displays information about passkeys and encourages users to enroll
/// in passkey authentication. It includes educational content about what passkeys
/// are and where they are stored, along with an action button to start passkey enrollment.
///
/// Availability: Requires iOS 16.6, macOS 13.5, or visionOS 1.0+
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct EnrollPasskeyView: View {

    @Environment(\.auth0Theme) private var theme
    /// Controls whether the passkey enrollment banner is displayed
    @Binding var collapsePasskeyBanner: Bool
    /// View model handling passkey enrollment logic
    @ObservedObject var viewModel: PasskeysEnrollmentViewModel

    var body: some View {
        VStack {
            Text("With Passkey, you don't have to remember complex passwords.")
                .auth0TextStyle(theme.typography.label)
                .foregroundStyle(theme.colors.text.bold)

            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text("What are passkeys?")
                        .auth0TextStyle(theme.typography.label)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.colors.text.bold)
                    Text("Passkeys are encrypted digital keys you create using your fingerprint, face, or screen lock.")
                        .auth0TextStyle(theme.typography.helper)
                        .foregroundStyle(theme.colors.text.bold)
                }
                Spacer()
            }.padding(.top, theme.spacing.xl)

            HStack {
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text("Where are passkeys saved?")
                        .auth0TextStyle(theme.typography.label)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.colors.text.bold)
                    Text("Passkeys are saved in your credential manager, so you can sign in on other devices.")
                        .auth0TextStyle(theme.typography.helper)
                        .foregroundStyle(theme.colors.text.bold)
                }
                Spacer()
            }.padding(.top, theme.spacing.xl)

            Button {
                Task {
                    await viewModel.startEnrollment()
                }
            } label: {
                Label {
                    Text("Add a Passkey")
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.background.primary)
                } icon: {
                    Image("passkey", bundle: ResourceBundle.default)
                        .resizable()
                        .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
                }.frame(maxWidth: .infinity)
            }
            .disabled(viewModel.showLoader)
            .frame(height: theme.sizes.buttonHeight)
            .background(
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: theme.colors.background.primary.opacity(0), location: 0.00),
                        Gradient.Stop(color: theme.colors.background.primary.opacity(0.05), location: 1.00)
                    ],
                    startPoint: UnitPoint(x: 0.5, y: 0),
                    endPoint: UnitPoint(x: 0.5, y: 1)
                )
            )
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.button))
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.button)
                    .inset(by: 0.5)
                    .stroke(theme.colors.background.primary.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 2, x: 0, y: 1)
            .padding(.top, theme.spacing.md)

            Button {
                withAnimation {
                    collapsePasskeyBanner.toggle()
                }
            } label: {
                Text("Remind me later")
                    .auth0TextStyle(theme.typography.label)
                    .foregroundStyle(theme.colors.background.primary)
            }
            .frame(height: theme.sizes.buttonHeight)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.button))
            .padding(.top, theme.spacing.xs)

        }
        .padding(.all, theme.spacing.lg)
        .background(Color("Muted", bundle: ResourceBundle.default))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium))
        .fullScreenCover(isPresented: $viewModel.showLoader) {
            Auth0Loader()
                .interactiveDismissDisabled(true)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.errorViewModel != nil },
                set: { if !$0 { viewModel.errorViewModel = nil } }
            )
        ) {
            if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel.dismissable {
                    viewModel.errorViewModel = nil
                })
            }
        }
    }
}
