import SwiftUI
import Auth0UIComponents
import Auth0

@main
struct AppUIComponentsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ContentViewModel())
                .onAppear {
                    Auth0UIComponentsSDKInitializer.initialize(tokenProvider: CredentialsManager(authentication: Auth0.authentication()))
                }
        }
    }
}
