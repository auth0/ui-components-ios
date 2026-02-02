import SwiftUI
import Auth0UIComponents
import Auth0

struct ContentView: View {
    // MARK: - Properties
    @State var viewAuthMethods: Bool = false
    @StateObject private var viewModel: ContentViewModel = ContentViewModel()
    @State private var isThemeSwitchingSheetShown: Bool = false
    
    // MARK: - Main body
    var body: some View {
        let _ = Self._printChanges()
        
        ZStack {
            if viewAuthMethods == true,
               let route = viewModel.route,
               case Route.landingScreen = route {
                MyAccountAuthMethodsView()
                    .onLongPressGesture {
                        viewAuthMethods.toggle()
                    }
            } else {
                VStack(spacing: 20) {
                    Button("Login") {
                        Auth0.webAuth()
                            .scope("openid profile email offline_access")
                            .start { result in
                                switch result {
                                case .success(let credentials):
                                    viewModel.storeCredentials(credentials)
                                    viewModel.getCredentials()
                                case .failure:
                                    break
                                }
                            }
                    }
                    .themeButtonStyle(.ghost)
                    
                    Button("Logout") {
                        Auth0.webAuth()
                            .clearSession(federated: false) { result in
                                switch result {
                                case .success(_):
                                    viewModel.clearCredentials()
                                    break
                                case .failure:
                                    break
                                }
                            }
                    }
                    .themeButtonStyle(.ghost)
                    
                    Button("Manage Authenticators") {
                        viewAuthMethods.toggle()
                    }
                    .themeButtonStyle(.ghost)
                    
                    Button("Switch Theme") {
                        isThemeSwitchingSheetShown.toggle()
                    }
                    .themeButtonStyle(.ghost)
                    
                    Text(viewModel.loginStatusMessage)
                        .foregroundStyle(Color.black)
                        .font(.system(size: 16, weight: .semibold))
                        .padding()
                    
                    Spacer()
                }
                .sheet(isPresented: $isThemeSwitchingSheetShown) {
                    ThemeSettingsView()
                }
            }
        }.onAppear {
            viewModel.getCredentials()
        }
        .onChange(of: isThemeSwitchingSheetShown) { _ in
            debugPrint("View Model: \(Unmanaged.passUnretained(viewModel).toOpaque())")
        }
    }
}
