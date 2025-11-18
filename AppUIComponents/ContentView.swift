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
                                    break
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
