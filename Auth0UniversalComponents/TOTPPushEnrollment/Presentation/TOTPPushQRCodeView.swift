import SwiftUI

/// View for displaying QR code for TOTP or push notification enrollment.
///
/// Shows a QR code that users can scan with their authenticator app (for TOTP)
/// or other MFA setup process. Also provides a manual entry code option for
/// cases where QR code scanning is not possible.
struct TOTPPushQRCodeView: View {

    // MARK: - Theme
    @Environment(\.auth0Theme) private var theme
    // MARK: - Navigation
    @EnvironmentObject private var router: Router<Route>
    // MARK: - View Model
    @StateObject private var viewModel: TOTPPushQRCodeViewModel

    // MARK: - State properties
    /// Drives the OTP sheet — non-nil presents the sheet, nil dismisses it
    @State private var otpSheetItem: OTPSheetItem?
    /// Pending navigation route to push after the OTP sheet dismisses
    @State private var pendingNavigationRoute: Route?

    // MARK: - Init
    /// Initializes the TOTP/Push QR code view.
    ///
    /// - Parameter viewModel: The view model managing QR code state and enrollment
    init(viewModel: TOTPPushQRCodeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Main body
    var body: some View {
        ZStack {
            if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel)
            } else {
                VStack {
                    if let qrCodeImage = viewModel.qrCodeImage {
                        qrCodeImage
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(1.0, contentMode: .fit)
                            .padding(.horizontal)

                        Text(
                            "Use your Authenticator App (like Google Authenticator or Auth0 Guardian) " +
                            "to scan this QR code."
                        )
                            .auth0TextStyle(theme.typography.body)
                            .foregroundStyle(theme.colors.text.regular)
                            .multilineTextAlignment(.center)
                    }

                    if let manualInputCode = viewModel.manualInputCode {
                        Text(manualInputCode)
                            .auth0TextStyle(theme.typography.helper)
                            .foregroundStyle(theme.colors.text.bold)
                            .padding(EdgeInsets(top: 10, leading: theme.spacing.sm, bottom: 10, trailing: theme.spacing.sm))
                            .overlay {
                                RoundedRectangle(cornerRadius: theme.radius.inputField)
                                    .stroke(theme.colors.background.primary, lineWidth: 1)
                            }.padding(.bottom, theme.spacing.md)

                        Button {
                            #if os(macOS)
                            NSPasteboard.general.setString(manualInputCode, forType: .string)
                            #else
                            UIPasteboard.general.string = manualInputCode
                            #endif
                            viewModel.toast = Toast(style: .notify, message: "Copied")
                        } label: {
                            HStack(alignment: .center, spacing: theme.spacing.xs) {
                                Image("copy", bundle: ResourceBundle.default)
                                    .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)

                                Text("Copy as Code")
                                    .auth0TextStyle(theme.typography.label)
                                    .foregroundStyle(theme.colors.background.primary)
                            }.padding().frame(maxWidth: .infinity)
                        }
                        .frame(height: theme.sizes.buttonHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radius.pill)
                                .stroke(theme.colors.background.primary, lineWidth: 2)
                        )
                        .cornerRadius(theme.radius.pill)
                    }

                    Button {
                        Task {
                            await viewModel.handleContinueButtonTap()
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

                    Text(attributedString())
                        .foregroundStyle(theme.colors.text.regular)
                        .auth0TextStyle(theme.typography.body)
                        .multilineTextAlignment(.center)
                        .onTapGesture {
                            if let url = URL(string: "https://apps.apple.com/us/app/auth0-guardian/id1093447833") {
                                #if os(macOS)
                                    NSWorkspace.shared.open(url)
                                #else
                                    UIApplication.shared.open(url)
                                #endif
                            }
                        }
                }
                .padding(.all, theme.spacing.md)
            }

            if viewModel.showLoader {
                Auth0Loader()
            }
        }
        .toastView(toast: $viewModel.toast)
        .navigationTitle(viewModel.navigationTitle())
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            Task {
                await viewModel.fetchEnrollmentChallenge()
            }
        }
        .onChange(of: viewModel.navigationRoute) { _ in
            guard let route = viewModel.navigationRoute else { return }
            router.navigate(to: route)
        }
        .onChange(of: viewModel.otpSheetConfig) { _ in
            guard let config = viewModel.otpSheetConfig else { return }
            otpSheetItem = OTPSheetItem(
                viewModel: OTPViewModel(
                    totpEnrollmentChallenge: config.totpEnrollmentChallenge,
                    emailEnrollmentChallenge: config.emailEnrollmentChallenge,
                    phoneEnrollmentChallenge: config.phoneEnrollmentChallenge,
                    type: config.type,
                    emailOrPhoneNumber: config.emailOrPhoneNumber,
                    delegate: nil,
                    onSuccess: { type in
                        pendingNavigationRoute = .filteredAuthListScreen(type: type, authMethods: [])
                        otpSheetItem = nil
                    }
                )
            )
        }
        .sheet(item: $otpSheetItem, onDismiss: {
            viewModel.otpSheetConfig = nil
            if let route = pendingNavigationRoute {
                router.navigate(to: route)
                pendingNavigationRoute = nil
            }
        }) { item in
            OTPView(viewModel: item.viewModel)
        }
    }

    // MARK: - Sheet item
    private struct OTPSheetItem: Identifiable {
        let id = UUID()
        let viewModel: OTPViewModel
    }

    func attributedString() -> AttributedString {
        var attributed = AttributedString("Don't have the Auth0 Guardian App?\nDownload it here")
        if let range = attributed.range(of: "Download it here") {
            attributed[range].foregroundColor = theme.colors.text.bold
            attributed[range].underlineStyle = .single
        }
        return attributed
    }
}
