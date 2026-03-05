import SwiftUI
import Auth0

/// View for displaying and saving recovery codes.
///
/// Shows generated recovery codes that users should save securely as backup
/// authentication methods. These codes can be used to sign in if their primary
/// authentication methods are unavailable.
struct RecoveryCodeEnrollmentView: View {

    @Environment(\.auth0Theme) private var theme
    /// View model managing recovery code state and enrollment logic
    @StateObject private var viewModel: RecoveryCodeEnrollmentViewModel

    /// Initializes the recovery code enrollment view.
    ///
    /// - Parameter viewModel: The view model managing recovery code state and enrollment
    init(viewModel: RecoveryCodeEnrollmentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            if viewModel.showLoader {
                Auth0Loader()
            } else if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel)
            } else {
                VStack {
                    Spacer()
                    Text("Save your recovery code")
                        .auth0TextStyle(theme.typography.displayMedium)
                        .foregroundStyle(theme.colors.text.bold)
                        .padding(.bottom, theme.spacing.sm)

                    Text(
                        "Save these codes in a secure location. They are your backup sign-in " +
                        "method if your multifactor device is unavailable. Each code may only be used once"
                    )
                        .multilineTextAlignment(.center)
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.text.regular)
                        .padding(.bottom, theme.spacing.xxl)

                    HStack {
                        Text("Recovery code")
                            .auth0TextStyle(theme.typography.label)
                            .foregroundStyle(theme.colors.text.bold)
                            .padding(.bottom, theme.spacing.md)
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        Text(viewModel.recoveryCodeChallenge?.recoveryCode ?? "")
                            .auth0TextStyle(theme.typography.label)
                            .foregroundStyle(theme.colors.text.bold)
                        Spacer()
                    }
                    .padding(EdgeInsets(top: 10, leading: theme.spacing.sm, bottom: 10, trailing: theme.spacing.sm))
                    .frame(height: theme.sizes.containerSizeLargeDimen)
                    .cornerRadius(theme.radius.inputField)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.inputField)
                            .stroke(theme.colors.background.primary, lineWidth: 1)
                    )
                    .padding(.bottom, theme.spacing.xxl)

                    Button {
                        if let recoveryCodeChallenge = viewModel.recoveryCodeChallenge {
                            #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.writeObjects([recoveryCodeChallenge.recoveryCode as NSString])
                            #elseif os(iOS) || os(visionOS)
                                UIPasteboard.general.string = recoveryCodeChallenge.recoveryCode
                            #endif
                            viewModel.toast = Toast(style: .notify, message: "Copied")
                        }
                    } label: {
                        Text("Copy Code")
                            .auth0TextStyle(theme.typography.label)
                            .foregroundStyle(theme.colors.background.primary)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: theme.sizes.buttonHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.pill)
                            .stroke(theme.colors.background.primary, lineWidth: 2)
                    )
                    .cornerRadius(theme.radius.pill)
                    .padding(.bottom, theme.spacing.xxl)

                    Button {
                        Task {
                            await viewModel.confirmEnrollment()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.apiCallInProgress {
                                Auth0Loader(tintColor: theme.colors.text.onPrimary)
                            } else {
                                Text("Continue")
                                    .foregroundStyle(theme.colors.text.onPrimary)
                                    .auth0TextStyle(theme.typography.label)
                            }
                            Spacer()
                        }.frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacing.sm)
                    }
                    .frame(height: theme.sizes.buttonHeight)
                    .background(theme.colors.background.primary)
                    .cornerRadius(theme.radius.button)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.button)
                            .stroke(theme.colors.background.primary, lineWidth: 2)
                    )
                    .padding(.bottom, 30)

                    Spacer()
                }.padding()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
        .toastView(toast: $viewModel.toast)
        .navigationTitle(Text("Recovery code"))
        #if os(iOS) || os(watchOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
