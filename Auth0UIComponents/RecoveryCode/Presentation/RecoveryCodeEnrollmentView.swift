import SwiftUI
import Auth0

struct RecoveryCodeEnrollmentView: View {
    @ObservedObject var viewModel: RecoveryCodeEnrollmentViewModel
    var body: some View {
        ZStack {
            if viewModel.showLoader {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
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
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color("262420", bundle: ResourceBundle.default), lineWidth: 1)
                        ).padding(.bottom, 40)
                    
                    Button {
                        if let recoveryCodeChallenge = viewModel.recoveryCodeChallenge {
                            UIPasteboard.general.string = recoveryCodeChallenge.recoveryCode
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
                        viewModel.confirmEnrollment()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(Color.white)
                            .font(.system(size: 16, weight: .medium))
                            .padding(.vertical, 12)
                    }.frame(height: 48)
                        .background(Color("262420", bundle: ResourceBundle.default))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.bottom, 30)
                    Spacer()
                }.padding()
            }
        }.onAppear {
            viewModel.loadData()
        }
        .navigationTitle(Text("Recovery code"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
