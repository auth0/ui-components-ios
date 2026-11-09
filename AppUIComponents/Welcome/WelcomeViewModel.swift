import SwiftUI
import Combine
import Auth0

struct WelcomeOptionsModel: Identifiable {
    let id = UUID().uuidString
    var icon: String
    var title: String
    var route: SampleAppRoute?
}

class WelcomeViewModel: ObservableObject {
    
    // MARK: - Properties
    @Published var userName: String = ""
    @Published var options: [WelcomeOptionsModel] = []
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
    
    // MARK: - Init
    init() {
        self.options = [
            WelcomeOptionsModel(icon: "ic_login_and_security", title: "Login & Security", route: .landing)]
        userName = (try? credentialsManager.userProfile())?.name ?? ""
        
        fetchAndUpdateOptions()
    }
    
    /// Embedded Login has no browser session, so it only clears local credentials.
    func performLogout(withCompletion completion: @escaping () -> Void) {
        guard LoginSession.method != .embedded else {
            clearLocalSession()
            completion()
            return
        }

        Auth0.webAuth()
            .logout(federated: false) { [weak self] result in
                switch result {
                case .success:
                    self?.clearLocalSession()
                    completion()
                case .failure(let error):
                    debugPrint("Error: \(error.localizedDescription)")
                }
            }
    }

    private func clearLocalSession() {
        try? credentialsManager.clear()
        LoginSession.clear()
    }
    
    /// Method to fetch available options
    func fetchAndUpdateOptions() {
        checkAndAddProfileOption()
        checkAndAddOtherOptions()
    }
    
    func checkAndAddProfileOption() {
        let user = try? credentialsManager.userProfile()
        let displayName = user?.name ?? user?.email ?? ""
        options.append(WelcomeOptionsModel(
            icon: "ic_person",
            title: "Profile",
            route: .profile(model: ProfileModel(
                name: displayName,
                givenName: user?.givenName,
                familyName: user?.familyName,
                email: user?.email,
                emailVerified: user?.emailVerified,
                lastUpdatedAt: user?.updatedAt
            ))
        ))
    }
    
    func checkAndAddOtherOptions() {
        options.append(contentsOf: [
            WelcomeOptionsModel(icon: "ic_tokens", title: "Tokens"),
            WelcomeOptionsModel(icon: "ic_sessions", title: "Sessions"),
            WelcomeOptionsModel(icon: "ic_docs", title: "Docs"),
            WelcomeOptionsModel(icon: "ic_favorites", title: "Favorites")
        ])
    }
}
