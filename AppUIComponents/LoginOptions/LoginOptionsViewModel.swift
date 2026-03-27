import SwiftUI
import Combine
import Auth0

@MainActor
final class LoginOptionsViewModel: ObservableObject {
    
    typealias LoginOptionModel = LoginOptionsView.LoginOptionsModel
    
    // MARK: - Published Properties
    @Published var loginOptionModels: [LoginOptionModel] = [.init(type: .hostedLogin,
                                                                   icon: "ic_hosted_login",
                                                                   title: "Hosted Login",
                                                                   description: "Easy to setup, works instantly"),
                                                            .init(type: .embeddedLogin,
                                                                   icon: "ic_embedded_login",
                                                                   title: "Embedded Login (coming soon)",
                                                                   description: "Total brand control and low user frictions")]
    @Published var navigationRoute: SampleAppRoute? = nil
    @Published var error: LoginError? = nil
    @Published var isLoading: Bool = false
    
    // MARK: - Properties
    private let credentialsManager: CredentialsManager
    private var cancellables: Set<AnyCancellable> = []
    
    init(authentication: Authentication = Auth0.authentication()) {
        self.credentialsManager = CredentialsManager(authentication: authentication)
    }
    
    // MARK: - Methods
    func checkAuthentication() async -> SampleAppRoute? {
        do {
            let isAuthenticated = try await credentialsManager.credentials()
                .values
                .first { _ in true }
            
            return (isAuthenticated != nil) ? .welcome : nil
        } catch {
            debugPrint("Check authentication failed!!!")
            return nil
        }
    }
    
    private func storeCredentials(_ credentials: Credentials) {
        let _ = credentialsManager.store(credentials: credentials)
    }
    
    func performUniversalLogin() {
        isLoading = true
        Auth0.webAuth()
            .scope("openid profile email offline_access")
            .start { [weak self] result in
                switch result {
                case .success(let credentials):
                    self?.storeCredentials(credentials)
                    self?.getCredentials()
                case .failure(let error):
                    self?.isLoading = false
                    self?.error = .init(webAuthError: error)
                }
            }
    }

    private func getCredentials() {
        credentialsManager.credentials()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    break
                case .failure:
                    self?.isLoading = false
                }
            } receiveValue: { [weak self] credentials in
                self?.isLoading = false
                self?.navigationRoute = .welcome
            }.store(in: &cancellables)
    }
}
