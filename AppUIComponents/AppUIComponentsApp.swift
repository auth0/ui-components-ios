import SwiftUI
import Auth0UIComponents
import Auth0

@main
struct AppUIComponentsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ContentViewModel())
                .onAppear {
                    do {
                        try Auth0UIComponentsSDKInitializer.initialize(tokenProvider: CredentialsManager(authentication: Auth0.authentication()))
                    } catch {
                        // handle error while initialization
                    }
                }
        }
    }
}
