import SwiftUI
import Auth0
import Auth0UniversalComponents

struct ViewFactory {
    @ViewBuilder
    static func view(for route: SampleAppRoute) -> some View {
        switch route {
        case .splash:
            SplashView()
        case .loginOptions:
            let viewModel = LoginOptionsViewModel()
            LoginOptionsView(viewModel: viewModel)
        case .landing:
            MyAccountAuthMethodsView()
                .embeddedInNavigationStack()
        case .welcome:
            let viewModel = WelcomeViewModel()
            WelcomeView(viewModel: viewModel)
        case .appearance:
            let viewModel = ThemeViewModel()
            ThemeView(viewModel: viewModel)
        case .profile(let model):
            let viewModel = ProfileViewModel(profile: model)
            ProfileView(viewModel: viewModel)
        case .embeddedLogin:
            EmbeddedLoginContainerView()
        }
    }
}

/// Hosts Embedded Login and routes to `.welcome` on success (needs the environment router).
///
/// The SDK stores nothing. It hands the credentials to this app, which keeps them where it keeps its session.
private struct EmbeddedLoginContainerView: View {
    @EnvironmentObject private var router: Router<SampleAppRoute>

    /// The same default store `WelcomeViewModel` reads from and clears at logout.
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())

    /// `Connection` key from `Auth0.plist`.
    private var connection: String? {
        guard let url = Bundle.main.url(forResource: "Auth0", withExtension: "plist"),
              let values = NSDictionary(contentsOf: url) else { return nil }
        return values["Connection"] as? String
    }

    var body: some View {
        EmbeddedLoginView(connection: connection) { credentials in
            // Replace any earlier session: Auth0.swift keeps its pinned session expiry until `clear()`.
            try? credentialsManager.clear()
            // Throwing shows the SDK's "couldn't save" screen and lets the user start again.
            try credentialsManager.store(credentials: credentials)
            LoginSession.record(.embedded)
            // One atomic swap; pop() + navigate() can be mis-diffed into a double push.
            router.replaceTop(with: .welcome)
        }
    }
}
