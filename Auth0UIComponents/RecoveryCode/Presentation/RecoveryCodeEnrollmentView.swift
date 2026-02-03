import SwiftUI
import Auth0

/// View for displaying and saving recovery codes.
///
/// Shows generated recovery codes that users should save securely as backup
/// authentication methods. These codes can be used to sign in if their primary
/// authentication methods are unavailable.
struct RecoveryCodeEnrollmentView: View {
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
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color("191919", bundle: ResourceBundle.default))
                        .padding(.bottom, 12)

                    Text("Save these codes in a secure location. They are your backup sign-in method if your multifactor device is unavailable. Each code may only be used once")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color("737373", bundle: ResourceBundle.default))
                        .padding(.bottom, 40)
                    HStack {
                        Text("Recovery code")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                            .padding(.bottom, 16)
                        Spacer()
                    }

                    HStack {
                        Spacer()
                        Text(viewModel.recoveryCodeChallenge?.recoveryCode ?? "")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                        Spacer()
                    }.padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                        .frame(height: 52)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color("262420", bundle: ResourceBundle.default), lineWidth: 1)
                        ).padding(.bottom, 40)
                    
                    Button {
                        if let recoveryCodeChallenge = viewModel.recoveryCodeChallenge {
                            #if os(macOS)
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.writeObjects([recoveryCodeChallenge.recoveryCode as NSString])
                            #elseif os(iOS) && os(visionOS)
                                UIPasteboard.general.string = recoveryCodeChallenge.recoveryCode
                            #endif
                            viewModel.toast = Toast(style: .notify, message: "Copied")
                        }
                    } label: {
                        Text("Copy Code")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color("262420", bundle: ResourceBundle.default))
                            .frame(maxWidth: .infinity)
                    }.frame(height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 24)
                            .stroke(Color("262420", bundle: ResourceBundle.default), lineWidth: 2)
                        ).cornerRadius(24)
                        .padding(.bottom, 40)

                    Button {
                        Task {
                            await viewModel.confirmEnrollment()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.apiCallInProgress {
                                Auth0Loader(tintColor: Color("FFFFFF", bundle: ResourceBundle.default))
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
                    Spacer()
                }.padding()
            }
        }.onAppear {
            Task {
                await viewModel.loadData()
            }
        }.toastView(toast: $viewModel.toast)
        .navigationTitle(Text("Recovery code"))
        #if os(iOS) || os(watchOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
