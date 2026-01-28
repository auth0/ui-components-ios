import Combine
import Foundation
import Auth0

public enum Route: Hashable {
    case landingScreen
}

@MainActor
final class ContentViewModel: ObservableObject {
    private let credentialsManager = CredentialsManager(authentication: Auth0.authentication())
    private var cancellables: Set<AnyCancellable> = []
    @Published var route: Route? = nil
    @Published var loginStatusMessage: String = ""
    func storeCredentials(_ credentials: Credentials) {
        let _ = credentialsManager.store(credentials: credentials)
    }

    func clearCredentials() {
       _ = credentialsManager.clear()
        loginStatusMessage = "Not logged in"
    }

    func getCredentials() {
        credentialsManager.credentials()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                guard let self else { return }
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    loginStatusMessage = "Not logged in \(error.debugDescription)"
                    break
                }
            } receiveValue: { [weak self] credentials in
                guard let self else { return }
                loginStatusMessage = "Logged in \n AccessToken: \(credentials.accessToken)"
                route = .landingScreen
            }.store(in: &cancellables)
    }
}
