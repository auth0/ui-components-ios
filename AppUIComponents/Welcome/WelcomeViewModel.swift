import SwiftUI
import Combine
import Auth0
import Auth0UniversalComponents

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
        
        _ = credentialsManager.clear()
        
        completion()
    }
    
    /// Method to fetch avaialble options
    func fetchAndUpdateOptions() {
        checkAndAddProfileOption()
    }
    
    func checkAndAddProfileOption() {
        guard let user = credentialsManager.user else {
            return
        }
        
        if let name = user.name {
            options.append(WelcomeOptionsModel(icon: "ic_person", title: "Profile", route: .profile(model: .init(fromUserInfo: user,
                                                                                                                 withName: name))))
        }
    }
}
