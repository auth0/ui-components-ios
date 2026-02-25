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
                        .foregroundStyle(theme.colors.textPrimary)
                        .padding(.bottom, theme.spacing.md)

                    Text("Save these codes in a secure location. They are your backup sign-in method if your multifactor device is unavailable. Each code may only be used once")
                        .multilineTextAlignment(.center)
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.textSecondary)
                        .padding(.bottom, theme.spacing.`3xl`)

                    HStack {
                        Text("Recovery code")
                            .auth0TextStyle(theme.typography.label)
                            .foregroundStyle(theme.colors.textPrimary)
                            .padding(.bottom, theme.spacing.base)
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        Text(viewModel.recoveryCodeChallenge?.recoveryCode ?? "")
                            .auth0TextStyle(theme.typography.label)
                            .foregroundStyle(theme.colors.textPrimary)
                        Spacer()
                    }
                    .padding(EdgeInsets(top: 10, leading: theme.spacing.md, bottom: 10, trailing: theme.spacing.md))
                    .frame(height: theme.sizes.containerSizeLargeDimen)
                    .cornerRadius(theme.radius.inputField)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.inputField)
                            .stroke(theme.colors.primary, lineWidth: 1)
                    )
                    .padding(.bottom, theme.spacing.`3xl`)

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
                            .foregroundStyle(theme.colors.primary)
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: theme.sizes.buttonHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.pill)
                            .stroke(theme.colors.primary, lineWidth: 2)
                    )
                    .cornerRadius(theme.radius.pill)
                    .padding(.bottom, theme.spacing.`3xl`)

                    Button {
                        Task {
                            await viewModel.confirmEnrollment()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.apiCallInProgress {
                                Auth0Loader(tintColor: theme.colors.onPrimary)
                            } else {
                                Text("Continue")
                                    .foregroundStyle(theme.colors.onPrimary)
                                    .auth0TextStyle(theme.typography.label)
                            }
                            Spacer()
                        }.frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacing.md)
                    }
                    .frame(height: theme.sizes.buttonHeight)
                    .background(theme.colors.primary)
                    .cornerRadius(theme.radius.button)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.button)
                            .stroke(theme.colors.primary, lineWidth: 2)
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
