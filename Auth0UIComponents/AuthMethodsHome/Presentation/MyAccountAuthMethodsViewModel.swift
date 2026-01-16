
import Combine
import SwiftUI
import Auth0

enum MyAccountAuthViewComponentData: Hashable {
    case title(text: String)
    case subtitle(text: String)
    case additionalVerificationMethods(model: MyAccountAuthMethodViewModel)
    case emptyFactors
}

@MainActor
final class MyAccountAuthMethodsViewModel: ObservableObject {
    
    private let factorsUseCase: GetFactorsUseCaseable
    private let authMethodsUseCase: GetAuthMethodsUseCaseable

    @Published var viewComponents: [MyAccountAuthViewComponentData] = []
    @Published var errorViewModel: ErrorScreenViewModel? = nil
    @Published var showLoader: Bool = true
    private let dependencies: Auth0UIComponentsSDKInitializer
    
    private var factorsFetched: Bool = false
    private var authMethodsFetched: Bool = false
    private var factors: [Factor] = []
    private var authMethods: [AuthenticationMethod] = []
 
    init(factorsUseCase: GetFactorsUseCaseable = GetFactorsUseCase(),
         authMethodsUseCase: GetAuthMethodsUseCaseable = GetAuthMethodsUseCase(),
         dependencies: Auth0UIComponentsSDKInitializer = .shared) {
        self.factorsUseCase = factorsUseCase
        self.authMethodsUseCase = authMethodsUseCase
        self.dependencies = dependencies
    }

    func loadMyAccountAuthViewComponentData() async {
        errorViewModel = nil
        self.viewComponents = []
        showLoader = true

        do {
            if self.factorsFetched == false || self.authMethodsFetched == false {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                    audience: dependencies.audience,
                    scope: "openid read:me:factors read:me:authentication_methods"
                )

                async let factorsResponse = factorsUseCase.execute(
                    request: GetFactorsRequest(token: apiCredentials.accessToken, domain: dependencies.domain)
                )
                async let authMethodsResponse = authMethodsUseCase.execute(
                    request: GetAuthMethodsRequest(token: apiCredentials.accessToken, domain: dependencies.domain)
                )
                
                let (authMethods, factors) = try await (authMethodsResponse, factorsResponse)
                self.factors = factors
                self.authMethods = authMethods
                self.factorsFetched = true
                self.authMethodsFetched = true
            }

            showLoader = false

            let supportedFactors = self.factors.compactMap { AuthMethodType(rawValue: $0.type) }

            var viewComponents: [MyAccountAuthViewComponentData] = []
            viewComponents.append(.title(text: "Verification methods"))
            viewComponents.append(.subtitle(text: "Manage your 2FA methods"))

            if supportedFactors.isEmpty == false {
                for factor in supportedFactors  {
                    let filteredAuthMethods = self.authMethods.filter { $0.type == factor.rawValue }

                    viewComponents.append(.additionalVerificationMethods(model: MyAccountAuthMethodViewModel(
                        authMethods: filteredAuthMethods,
                        type: factor,
                        dependencies: dependencies
                    )))
                }

                self.viewComponents = viewComponents
            } else {
                self.viewComponents = [.emptyFactors]
            }
        } catch  {
            await handle(error: error, scope: "openid read:me:factors read:me:authentication_methods") { [weak self] in
                Task {
                    await self?.loadMyAccountAuthViewComponentData()
                }
            }
        }
    }

    func resetDataBeforeRefresing() {
        self.factorsFetched = false
        self.authMethodsFetched = false 
    }

    @MainActor func handle(error: Error,
                           scope: String,
                           retryCallback: @escaping () -> Void) async {
        showLoader = false
        
        if let error = error as? CredentialsManagerError {
            let uiComponentError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
            
            if case .mfaRequired = uiComponentError {
                showLoader = true
                
                do {
                    let credentials = try await Auth0.webAuth(
                        clientId: dependencies.clientId,
                        domain: dependencies.domain,
                        session: dependencies.session
                    )
                        .audience(dependencies.audience)
                        .scope(scope)
                        .start()
                    
                    await dependencies.tokenProvider.store(
                        apiCredentials: APICredentials(from: credentials),
                        for: dependencies.audience
                    )
                    
                    showLoader = false
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
        }
        else if let error  = error as? MyAccountError {
            let uiComponentError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
            errorViewModel = uiComponentError.errorViewModel(completion: {
                retryCallback()
            })
        }
        else if let error = error as? WebAuthError {
            let uiComponentError = Auth0UIComponentError.handleWebAuthError(error: error)
            errorViewModel = uiComponentError.errorViewModel {
                retryCallback()
            }
        }
    }
    
}

extension MyAccountAuthMethodsViewModel: RefreshAuthDataProtocol  {
    
    func refreshAuthData() {
        authMethodsFetched = false
        factorsFetched = false
    }
    
}
