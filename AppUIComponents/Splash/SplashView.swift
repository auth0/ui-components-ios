import SwiftUI
import Auth0UniversalComponents

struct SplashView: View {
    
    // MARK: - Router
    @EnvironmentObject var router: Router<SampleAppRoute>
    
    // MARK: - Main body
    var body: some View {
        GeometryReader { proxy in
            Image("ic_auth0", bundle: .main)
                .position(x: proxy.frame(in: .local).midX, y: proxy.frame(in: .local).midY)
        }.onAppear {
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
