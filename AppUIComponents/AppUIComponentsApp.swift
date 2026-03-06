import SwiftUI
import Auth0UniversalComponents
import Auth0

@main
struct AppUIComponentsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ContentViewModel())
                .auth0Theme(Auth0Theme())
                .onAppear {
                    Auth0UniversalComponentsSDKInitializer.initialize(tokenProvider: CredentialsManager(authentication: Auth0.authentication()))
                }
        }
    }
}
