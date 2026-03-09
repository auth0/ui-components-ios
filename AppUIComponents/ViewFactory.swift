//
//  ViewFactory.swift
//  Auth0UIComponents
//
//  Created by Sudhanshu Vohra on 09/02/26.
//

import SwiftUI
import Auth0UniversalComponents

struct ViewFactory {
    @ViewBuilder
    static func view(for route: SampleAppRoute) -> some View {
        switch route {
        case .splash:
            let viewModel = SplashViewModel()
            SplashView(viewModel: viewModel)
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
        }
    }
}
