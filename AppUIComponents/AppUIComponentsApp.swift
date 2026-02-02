import SwiftUI
import Auth0UIComponents
import Auth0

@main
struct AppUIComponentsApp: App {
    // MARK: - Theme Manager
    @StateObject private var themeManager = ThemeManager(theme: DefaultTheme())
    
    // MARK: - Main body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, themeManager.current)
                .environmentObject(themeManager) // Optional: for switching themes live
                .onAppear {
                    Auth0UIComponentsSDKInitializer.initialize(tokenProvider: CredentialsManager(authentication: Auth0.authentication()))
                }
        }
    }
}

#Preview("Flo Theme") {
    ContentView()
        .environmentObject(ThemeManager(theme: FloTheme()))
        .onAppear {
            Auth0UIComponentsSDKInitializer.initialize(tokenProvider: CredentialsManager(authentication: Auth0.authentication()))
        }
}

#Preview("GrandVision Theme") {
    ContentView()
        .environmentObject(ThemeManager(theme: GrandVisionTheme()))
        .onAppear {
            Auth0UIComponentsSDKInitializer.initialize(tokenProvider: CredentialsManager(authentication: Auth0.authentication()))
        }
}

#Preview("Default Theme") {
    ContentView()
        .environmentObject(ThemeManager(theme: DefaultTheme()))
        .onAppear {
            Auth0UIComponentsSDKInitializer.initialize(tokenProvider: CredentialsManager(authentication: Auth0.authentication()))
        }
}

