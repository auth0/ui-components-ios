import SwiftUI

struct TOTPPushQRCodeView: View {
    // MARK: - State Properties
    @State private var showCopiedAlert = false
    
    // MARK: - View Model
    @ObservedObject var viewModel: TOTPPushQRCodeViewModel
    
    // MARK: - Properties
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    // MARK: - Theme
    @Environment(\.appTheme) var theme

    // MARK: - Main body
    var body: some View {
        VStack(spacing: 16) {
            if viewModel.showLoader {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(Color("3C3C43", bundle: ResourceBundle.default))
                    .scaleEffect(1.5 )
                    .frame(width: 50, height: 50)
            } else if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel)
            } else {
                if let qrCodeImage = viewModel.qrCodeImage {
                    qrCodeImage
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(1.0, contentMode: .fit)
                        .padding(.horizontal)
                    
                    Text("Use your Authenticator App (like Google Authenticator or Auth0 Guardian) to scan this QR code.")
                        .textStyle(.bodySmall)
                        .multilineTextAlignment(.center)
                }
                
                if let manualInputCode = viewModel.manualInputCode {
                    Text(manualInputCode)
                        .font(.system(size: 14))
                        .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color("262420", bundle: ResourceBundle.default), lineWidth: 1)
                        }.padding(.bottom, 16)
                    
                    Button {
                        // Copy contents using common pasteboard instance
                        PasteboardManager.copy(manualInputCode)
                        viewModel.toast = Toast(style: .notify, message: "Copied")
                    } label: {
                        HStack(alignment: .center, spacing: 8) {
                            Image("copy", bundle: ResourceBundle.default)
                                .frame(width: 16, height: 16)
                            
                            Text("Copy as Code")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color("262420", bundle: ResourceBundle.default))
                        }.padding().frame(maxWidth: .infinity)
                    }.frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color("262420", bundle: ResourceBundle.default), lineWidth: 2)
                        )
                        .cornerRadius(24)
                }
                
                VStack(spacing: 32) {
                    Button {
                        Task {
                            await viewModel.handleContinueButtonTap()
                        }
                    } label: {
                        HStack(alignment: .center) {
                            if viewModel.apiCallInProgress {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .tint(Color("FFFFFF", bundle: ResourceBundle.default))
                            } else {
                                Text("Continue")
                                    .foregroundStyle(AnyShapeStyle(Color.white))
                                    .textStyle(.label)
                            }
                        }.frame(maxWidth: .infinity)
                    }
                    .themeButtonStyle(.primary)
                    
                    Text(attributedString())
                        .textStyle(.bodySmall)
                        .multilineTextAlignment(.center)
                        .onTapGesture {
                            if let url = URL(string: "https://apps.apple.com/us/app/auth0-guardian/id1093447833") {
                                openExternalLink(url)
                            }
                        }
                }
            }
        }.padding(.all, 16)
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
    }
    
    func attributedString() -> AttributedString {
        var attributed = AttributedString("Don’t have the Auth0 Guardian App?\nDownload it here")
        if let range = attributed.range(of: "Download it here") {
            attributed[range].foregroundColor = Color("000000", bundle: ResourceBundle.default)
            attributed[range].underlineStyle = .single
        }
        return attributed
    }
}
