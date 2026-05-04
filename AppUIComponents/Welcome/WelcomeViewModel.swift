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
        userName = credentialsManager.user?.name ?? ""
        
        fetchAndUpdateOptions()
    }
    
    /// Method to perform logout
    func performLogout(withCompletion completion: @escaping () -> Void) {
        // Clear the web browser cookies
        Auth0.webAuth()
            .clearSession(federated: false) { [weak self] result in
                switch result {
                case .success(_):
                    
                    // Clears the crendtials stored in keychain after the web session is successfully cleared
                    _ = self?.credentialsManager.clear()
                    
                    completion()
                    break
                case .failure(let error):
                    debugPrint("Error: \(error.localizedDescription)")
                    break
                }
            }
    }
    
    /// Method to fetch available options
    func fetchAndUpdateOptions() {
        checkAndAddProfileOption()
        checkAndAddOtherOptions()
    }
    
    func checkAndAddProfileOption() {
        guard let user = credentialsManager.user else {
            return
        }
        let displayName = user.name ?? user.email ?? ""
        options.append(WelcomeOptionsModel(icon: "ic_person", title: "Profile", route: .profile(model: .init(fromUserInfo: user,
                                                                                                             withName: displayName))))
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
