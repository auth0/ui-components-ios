
import Combine
import SwiftUI
import Auth0

enum MyAccountAuthViewComponentData: Hashable {
    case title(text: String)
    case subtitle(text: String)
    case authMethod(model: MyAccountAuthMethodViewModel)
}

@MainActor
final class MyAccountAuthMethodsViewModel: ObservableObject {
    private let factorsUseCase: GetFactorsUseCaseable
    private let authMethodsUseCase: GetAuthMethodsUseCaseable
    
    @Published var viewComponents: [MyAccountAuthViewComponentData] = []
    @Published var errorViewModel: ErrorScreenViewModel? = nil
    @Published var showLoader: Bool = true
    private let dependencies: Dependencies
    
    init (session: URLSession = .shared,
          factorsUseCase: GetFactorsUseCaseable = GetFactorsUseCase(),
          authMethodsUseCase: GetAuthMethodsUseCaseable = GetAuthMethodsUseCase(),
          dependencies: Dependencies = .shared) {
        self.factorsUseCase = factorsUseCase
        self.authMethodsUseCase = authMethodsUseCase
        self.dependencies = dependencies
    }
    
    func loadMyAccountAuthViewComponentData() {
        Task {
            errorViewModel = nil
            self.viewComponents = []
            showLoader = true
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid read:me:factors read:me:authentication_methods")
                async let factorsResponse = factorsUseCase.execute(request: GetFactorsRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
                async let authMethodsResponse = authMethodsUseCase.execute(request: GetAuthMethodsRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
                let (authMethods, factors) = try await (authMethodsResponse, factorsResponse)
                let supportedFactors = factors.compactMap { AuthMethodType(rawValue: $0.type) }
                showLoader = false
                if supportedFactors.isEmpty == false {
                    var viewComponents: [MyAccountAuthViewComponentData] = []
                    viewComponents.append(.title(text: "Verification methods"))
                    viewComponents.append(.subtitle(text: "Manage your 2FA methods"))
                    for factor in supportedFactors  {
                        let filteredAuthMethods = authMethods.filter { $0.type == factor.rawValue }
                        viewComponents.append(.authMethod(model: MyAccountAuthMethodViewModel(authMethods: filteredAuthMethods,
                                                                                              type: factor,
                                                                                              dependencies: dependencies)))
                    }
                    self.viewComponents = viewComponents
                } else {
                    // TODO: handle factors empty error
                    errorViewModel = ErrorScreenViewModel(title: "Something went wrong", subTitle: "", buttonTitle: "", buttonClick: { [weak self] in
                        self?.loadMyAccountAuthViewComponentData()
                    })
                }
            } catch  {
                await handle(error: error, scope: "openid read:me:factors read:me:authentication_methods") { [weak self] in
                    self?.loadMyAccountAuthViewComponentData()
                }
            }
        }
    }
        
    @MainActor func handle(error: Error,
                           scope: String,
                           retryCallback: @escaping () -> Void) async {
        showLoader = false
        if let error = error as? CredentialsManagerError {
            let uiComponentError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
            if case .mfaRequired = uiComponentError {
                do {
                    let credentials = try await Auth0.webAuth()
                        .audience(dependencies.audience)
                        .scope(scope)
                        .start()
                    dependencies.tokenProvider.store(apiCredentials: APICredentials(from: credentials), for: dependencies.audience)
                    retryCallback()
                } catch  {
                    await handle(error: error,
                                 scope: scope,
                                 retryCallback: retryCallback)
                }
            } else {
                errorViewModel = uiComponentError.errorViewModel(completion: {
                    retryCallback()
                })
            }
        } else if let error  = error as? MyAccountError {
            let uiComponentError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
            errorViewModel = uiComponentError.errorViewModel(completion: {
                retryCallback()
            })
        }
    }
}
