import SwiftUI
import Auth0UniversalComponents
import Auth0

@main
struct AppUIComponentsApp: App {
    @StateObject private var router = Router<SampleAppRoute>()
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                // Initial View
                ViewFactory.view(for: .splash)
                    .onAppear {
                        // Important step Auth0 SDK initilization
                        Auth0UniversalComponentsSDKInitializer.initialize(tokenProvider: CredentialsManager(authentication: Auth0.authentication()))
                    }
                    .navigationDestination(for: SampleAppRoute.self) { route in
                        ViewFactory.view(for: route)
                    }
            }
            .environment(\.hostNavigationPath, $router.path)
            .auth0Theme(themeManager.currentTheme)
            .environmentObject(router)
            .environmentObject(themeManager)
        }
    }
}
