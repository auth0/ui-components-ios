//
//  WelcomeViewModel.swift
//  Auth0UIComponents
//
//  Created by Sudhanshu Vohra on 09/02/26.
//

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
    @Published var options: [WelcomeOptionsModel] = []
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
    
    init() {
        self.options = [
            WelcomeOptionsModel(icon: "ic_login_and_security", title: "Login & Security", route: .landing)]
    }
    
    func performLogout(withCompletion completion: @escaping () -> Void) {
        
        _ = credentialsManager.clear()
        
        completion()
        
        // TODO: - Fix the pop-up appearing issue
//        Auth0.webAuth()
//            .clearSession(federated: false) { [weak self] result in
//                switch result {
//                case .success(_):
//                    _ = self?.credentialsManager.clear()
//                    completion()
//                    break
//                case .failure(let error):
//                    debugPrint("Error: \(error.debugDescription)")
//                    completion()
//                    break
//                }
//            }
    }
}
