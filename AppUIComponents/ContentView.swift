import SwiftUI
import Auth0UIComponents
import Auth0

struct ContentView: View {
    @State var viewAuthMethods: Bool = false
    @ObservedObject var viewModel: ContentViewModel
    var body: some View {
        ZStack {
            if viewAuthMethods == true,
               let route = viewModel.route,
               case Route.landingScreen = route {
                MyAccountAuthMethodsView()
                    .environment(\.customTheme, Auth0UIComponentCustomTheme(myAccountAuthTheme: MyAccountAuthMethodTheme(navTheme: NavTheme(titleColor: Color("000000", bundle: ResourceBundle.default), titleFont: Font.system(size: 17)), backgroundColor: Color.white, title2Theme: TextTheme(color: Color.black, font: Font.system(size: 16)), cellTheme: MyAccountAuthCellTheme(cornerRadius: 10, backgroundColor: Color.blue, borderColor: Color.gray, borderWidth: 1, title2Theme: TextTheme(color: Color.black, font: .system(size: 16)), title3Theme: TextTheme(color: Color.blue, font: .system(size: 16)))), qrTheme: QRTheme(navTheme: NavTheme(titleColor: Color.blue, titleFont: .system(size: 16)), copyTextTheme: CopyTextTheme(titleColor: Color.yellow, titleFont: .system(size: 16), backgroundColor: .white, borderColor: .clear, cornerRadius: 20)), recoveryCodeTheme: RecoveryCodeTheme(navTheme: NavTheme(titleColor: Color.blue, titleFont: .system(size: 16)), copyTextTheme: CopyTextTheme(titleColor: Color.blue, titleFont: .system(size: 16), backgroundColor: .white, borderColor: .gray, cornerRadius: 10), backgroundColor: .white), enrolledFactorsTheme: EnrolledFactorsTheme(navTheme: NavTheme(titleColor: Color.blue, titleFont: .system(size: 16)), backgroundColor: Color.white, cellTheme: EnrolledFactorsCellTheme(titleColor: Color.black, titleFont: .system(size: 16), backgroundColor: .white, cornerRadius: 20, borderColor: .gray, borderWidth: 1.0)), otpTheme: OTPTheme(navTheme: NavTheme(titleColor: Color.blue, titleFont: .system(size: 16)), backgroundColor: .white, titleTheme: TextTheme(color: Color.blue, font: .system(size: 16)), otpTextFieldTheme: OTPTextFieldTheme(highlightColor: .gray, normalColor: .black, cornerRadius: 4, borderColor: .clear, borderWidth: 0.0, textTheme: TextTheme(color: .black, font: .system(size: 16))))))
            } else {
                VStack {
                    Button("Login") {
                        Auth0.webAuth()
                            .scope("openid profile email offline_access")
                            .start { result in
                                switch result {
                                case .success(let credentials):
                                    viewModel.storeCredentials(credentials)
                                    viewModel.getCredentials()
                                case .failure(let error):
                                    print(error)
                                }
                            }
                    }.frame(height: 50)

                    Button("Logout") {
                        Auth0.webAuth()
                            .clearSession(federated: false) { result in
                                switch result {
                                case .success(_):
                                    viewModel.clearCredentials()
                                    break
                                case .failure(let error):
                                    break
                                }
                            }
                    }.frame(height: 50)
                    
                    
                    Button("View") {
                        viewAuthMethods.toggle()
                    }
                    
                    Spacer()
                }
            }
        }.onAppear {
            viewModel.getCredentials()
        }
    }
}
