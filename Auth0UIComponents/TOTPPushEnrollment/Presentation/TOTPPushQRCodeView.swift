import SwiftUI

struct TOTPPushQRCodeView: View {
    @ObservedObject var viewModel: TOTPPushQRCodeViewModel
    @State private var showCopiedAlert = false
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        VStack {
            if viewModel.showLoader {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 100, height: 100)
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
                        .font(Font.system(size: 16))
                        .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
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
                        #if os(macOS)
                        NSPasteboard.general.setString(manualInputCode, forType: .string)
                        #else
                        UIPasteboard.general.string = manualInputCode
                        #endif
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

                Button {
                    viewModel.handleContinueButtonTap()
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.apiCallInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .tint(Color("FFFFFF", bundle: ResourceBundle.default))
                        } else {
                            Text("Continue")
                                .foregroundStyle(Color("FFFFFF", bundle: ResourceBundle.default))
                                .font(.system(size: 16, weight: .medium))
                        }
                        Spacer()
                    }.frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }.frame(height: 48)
                    .background(
                        Color("262420", bundle: ResourceBundle.default)
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color("262420", bundle: ResourceBundle.default),
                                lineWidth: 2
                            )
                    )
                    .padding(.bottom, 30)
                
            Text(attributedString())
                    .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                    .font(Font.system(size: 16))
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
        }.padding(.all, 16)
            .navigationTitle(viewModel.navigationTitle())
        #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .onAppear  {
                 viewModel.fetchEnrollmentChallenge()
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
