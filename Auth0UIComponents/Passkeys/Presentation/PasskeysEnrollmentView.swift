import SwiftUI

@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct PasskeysEnrollmentView: View {
    @ObservedObject var viewModel: PasskeysEnrollmentViewModel

    init(viewModel: PasskeysEnrollmentViewModel) {
        self.viewModel = viewModel
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
                            .padding(.vertical, 40)
                        
                        Text("Enable Passkey")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                            .padding(.bottom, 20)
                        HStack {
                            VStack(alignment: .leading) {
                                Text("What are passkeys?")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                                    .padding(.bottom, 4)
                                
                                Text("Passkeys are encrypted digital keys you create using your fingerprint, face, or screen lock.")
                                    .multilineTextAlignment(.leading)
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                                    .padding(.bottom, 30)
                                
                                Text("Where are passkeys saved?")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                                    .padding(.bottom, 4)
                                
                                Text("Passkeys are saved in your credential manager, so you can sign in on other devices.")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                                    .padding(.bottom, 30)
                            }
                            Spacer()
                        }
                        
                        Button {
                            Task {
                                await viewModel.startEnrollment()
                            }
                        } label: {
                            Text("Enable")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color("FFFFFF", bundle: ResourceBundle.default))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }.frame(height: 48)
                            .background(Color("262420", bundle: ResourceBundle.default))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.top, 30)
                        
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                            .onTapGesture {
                                NavigationStore.shared.popToRoot()
                            }
                            .padding(.top, 20)
                        Spacer()
                    }
                }.padding()
            }
        }
        .navigationTitle(Text("Enable Passkey"))
#if os(iOS) || os(watchOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }
}
