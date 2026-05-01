import SwiftUI

/// View for displaying QR code for TOTP or push notification enrollment.
///
/// Shows a QR code that users can scan with their authenticator app (for TOTP)
/// or other MFA setup process. Also provides a manual entry code option for
/// cases where QR code scanning is not possible.
struct TOTPPushQRCodeView: View {

    @Environment(\.auth0Theme) private var theme
    @EnvironmentObject private var router: Router<Route>
    /// View model managing QR code generation and enrollment state
    @StateObject private var viewModel: TOTPPushQRCodeViewModel
    /// Controls visibility of the "code copied" alert
    @State private var showCopiedAlert = false

    /// Initializes the TOTP/Push QR code view.
    ///
    /// - Parameter viewModel: The view model managing QR code state and enrollment
    init(viewModel: TOTPPushQRCodeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Core Image context for QR code rendering
    private let context = CIContext()
    /// QR code filter for generating QR codes
    private let filter = CIFilter.qrCodeGenerator()

    /// Generates a theme-coloured QR code image from a URI string.
    ///
    /// Uses `CIFalseColor` to replace the default black modules with
    /// `theme.colors.text.bold` and the white background with
    /// `theme.colors.background.layerTop`, so the QR code adapts automatically
    /// whenever the active theme changes.
    private func makeQRCodeImage(from uri: String) -> Image? {
        filter.correctionLevel = "H"
        filter.message = Data(uri.utf8)
        guard let rawOutput = filter.outputImage else { return nil }

        let colored: CIImage
        if let falseColor = CIFilter(name: "CIFalseColor") {
            #if canImport(UIKit)
            let fgCIColor = CIColor(color: UIColor(theme.colors.text.bold))
            let bgCIColor = CIColor(color: UIColor(theme.colors.background.layerTop))
            #elseif canImport(AppKit)
            let fgCIColor = CIColor(color: NSColor(theme.colors.text.bold)) ?? CIColor.black
            let bgCIColor = CIColor(color: NSColor(theme.colors.background.layerTop)) ?? CIColor.white
            #endif
            falseColor.setValue(rawOutput, forKey: "inputImage")
            falseColor.setValue(fgCIColor, forKey: "inputColor0")
            falseColor.setValue(bgCIColor, forKey: "inputColor1")
            colored = falseColor.outputImage ?? rawOutput
        } else {
            colored = rawOutput
        }

        guard let cgImage = context.createCGImage(colored, from: rawOutput.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1.0)
    }

    var body: some View {
        ZStack {
            if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel)
            } else {
                VStack {
                    Spacer(minLength: 0)
                    if let uri = viewModel.qrCodeURI, let qrCodeImage = makeQRCodeImage(from: uri) {
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
                                    .renderingMode(.template)
                                    .foregroundStyle(theme.colors.background.primary)
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
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.all, theme.spacing.md)
            }

            if viewModel.showLoader {
                Auth0Loader()
            }
        }
        .background(theme.colors.background.layerBase.ignoresSafeArea())
        .toastView(toast: $viewModel.toast)
        .themedNavigationTitle(viewModel.navigationTitle(), theme: theme)
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.colors.background.layerBase, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(theme.colors.text.bold)
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
