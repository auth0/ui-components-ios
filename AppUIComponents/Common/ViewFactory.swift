import SwiftUI
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
private struct EmbeddedLoginContainerView: View {
    @EnvironmentObject private var router: Router<SampleAppRoute>

    /// `Connection` key from `Auth0.plist`.
    private var connection: String? {
        guard let url = Bundle.main.url(forResource: "Auth0", withExtension: "plist"),
              let values = NSDictionary(contentsOf: url) else { return nil }
        return values["Connection"] as? String
    }

    var body: some View {
        EmbeddedLoginView(connection: connection) {
            LoginSession.record(.embedded)
            // One atomic swap; pop() + navigate() can be mis-diffed into a double push.
            router.replaceTop(with: .welcome)
        }
    }
}
