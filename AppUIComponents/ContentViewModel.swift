import Combine
import Foundation
import Auth0

public enum Route: Hashable {
    case landingScreen(refreshToken: String, audience: String)
}

@MainActor
final class ContentViewModel: ObservableObject {
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
    private var cancellables: Set<AnyCancellable> = []
    @Published var route: Route? = nil

    func storeCredentials(_ credentials: Credentials) {
        let _ = credentialsManager.store(credentials: credentials)
    }

    func clearCredentials() {
       _ = credentialsManager.clear()
       _ = credentialsManager.clear(forAudience: "")
    }

    func getCredentials() {
        credentialsManager.credentials()
            .receive(on: DispatchQueue.main)
            .sink { completion in
            } receiveValue: { [weak self] credentials in
                guard let self else { return }
                route = .landingScreen(refreshToken: credentials.refreshToken ?? "", audience: "")
            }.store(in: &cancellables)
    }
}
