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
        }
    }
}
