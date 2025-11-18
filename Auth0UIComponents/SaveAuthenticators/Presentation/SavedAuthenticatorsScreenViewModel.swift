import Auth0
import Combine

@MainActor
final class SavedAuthenticatorsScreenViewModel: ObservableObject {
    private let dependencies: Auth0UIComponentsSDKInitializer
    private let authenticationMethods: [AuthenticationMethod]
    let type: AuthMethodType
    private let getAuthMethodsUseCase: GetAuthMethodsUseCaseable
    private let deleteAuthMethodUseCase: DeleteAuthMethodUseCaseable
    @Published var showManageAuthSheet: Bool = false
    @Published var showLoader: Bool = true
    @Published var errorViewModel: ErrorScreenViewModel? = nil
    @Published var viewAuthenticationMethods: [AuthenticationMethod] = []
    init(dependencies: Auth0UIComponentsSDKInitializer = .shared,
         getAuthMethodsUseCase: GetAuthMethodsUseCaseable = GetAuthMethodsUseCase(),
         deleteAuthMethodsUseCase: DeleteAuthMethodUseCaseable = DeleteAuthMethodUseCase(),
         type: AuthMethodType,
         authenticationMethods: [AuthenticationMethod]) {
        self.dependencies = dependencies
        self.type = type
        self.getAuthMethodsUseCase = getAuthMethodsUseCase
        self.deleteAuthMethodUseCase = deleteAuthMethodsUseCase
        self.authenticationMethods = authenticationMethods
    }

    func deleteAuthMethod(authMethod: AuthenticationMethod) async {
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid delete:me:authentication_methods")
            try await deleteAuthMethodUseCase.execute(request: DeleteAuthMethodRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: authMethod.id))
            await loadData(true)
        } catch {
            await handle(error: error, scope: "openid delete:me:authentication_methods") { [weak self] in
                Task {
                    await self?.deleteAuthMethod(authMethod: authMethod)
                }
            }
        }
    }

    func loadData(_ postDeletion: Bool = false) async {
        viewAuthenticationMethods = []
        showLoader = true
        errorViewModel = nil
        guard postDeletion || authenticationMethods.isEmpty else {
            showLoader = false
            viewAuthenticationMethods = authenticationMethods
            return
        }
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid read:me:authentication_methods")
            let apiAuthMethods = try await getAuthMethodsUseCase.execute(request: GetAuthMethodsRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
            showLoader = false
            let filteredAuthMethods = apiAuthMethods.filter { $0.type == type.rawValue }
            if filteredAuthMethods.isEmpty {
                viewAuthenticationMethods = []
            } else {
                viewAuthenticationMethods = apiAuthMethods.filter { $0.type == type.rawValue }
            }
        } catch {
            await handle(error: error, scope: "openid read:me:authentication_methods") { [weak self] in
                Task {
                    await self?.loadData(postDeletion)
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
                showLoader = true
                do {
                    let credentials = try await Auth0.webAuth(clientId: dependencies.clientId,
                                                              domain: dependencies.domain,
                                                              session: dependencies.session)
                        .audience(dependencies.audience)
                        .scope(scope)
                        .start()
                    showLoader = false
                    await dependencies.tokenProvider.store(apiCredentials: APICredentials(from: credentials), for: dependencies.audience)
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
        } else if let error = error as? WebAuthError {
            let uiComponentError = Auth0UIComponentError.handleWebAuthError(error: error)
            errorViewModel = uiComponentError.errorViewModel(completion: {
                retryCallback()
            })
        }
    }
}

extension AuthenticationMethod {
    var displayTime: String {
        return ""
    }
}
