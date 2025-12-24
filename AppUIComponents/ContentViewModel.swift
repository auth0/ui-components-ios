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

    func storeCredentials(_ credentials: Credentials) {
        let _ = credentialsManager.store(credentials: credentials)
    }

    func clearCredentials() {
       _ = credentialsManager.clear()
    }

    func getCredentials() {
        credentialsManager.credentials()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    print(error)
                }
            } receiveValue: { [weak self] credentials in
                guard let self else { return }
                route = .landingScreen
            }.store(in: &cancellables)
    }
}
