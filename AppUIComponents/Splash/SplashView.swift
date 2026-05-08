import SwiftUI
import Auth0UniversalComponents

struct SplashView: View {

    // MARK: - Router
    @EnvironmentObject var router: Router<SampleAppRoute>

    // MARK: - Theme
    @Environment(\.auth0Theme) private var theme

    // MARK: - Main body
    var body: some View {
        GeometryReader { proxy in
            Image("ic_auth0", bundle: .main)
                .renderingMode(.template)
                .foregroundStyle(theme.colors.text.bold)
                .position(x: proxy.frame(in: .local).midX, y: proxy.frame(in: .local).midY)
        }
        .background(theme.colors.background.layerBase)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut.delay(2)) {
                navigateToLoginOptions()
            }
        }
    }
    
    // MARK: - Handle navigation
    func navigateToLoginOptions() {
        router.navigate(to: .loginOptions)
    }
}
