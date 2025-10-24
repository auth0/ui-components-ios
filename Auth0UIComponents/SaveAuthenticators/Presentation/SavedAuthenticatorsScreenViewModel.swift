import Auth0
import Combine

@MainActor
final class SavedAuthenticatorsScreenViewModel: ObservableObject {
    private let dependencies: Dependencies
    private let authenticationMethods: [AuthenticationMethod]
    let type: AuthMethodType
    private let getAuthMethodsUseCase: GetAuthMethodsUseCaseable
    private let deleteAuthMethodUseCase: DeleteAuthMethodUseCaseable
    @Published var showManageAuthSheet: Bool = false
    @Published var showLoader: Bool = true
    @Published var errorViewModel: ErrorScreenViewModel? = nil
    @Published var viewAuthenticationMethods: [AuthenticationMethod] = []
    init(dependencies: Dependencies = .shared,
         type: AuthMethodType,
         getAuthMethodsUseCase: GetAuthMethodsUseCaseable = GetAuthMethodsUseCase(),
         deleteAuthMethodsUseCase: DeleteAuthMethodUseCaseable = DeleteAuthMethodUseCase(),
         authenticationMethods: [AuthenticationMethod]) {
        self.dependencies = dependencies
        self.type = type
        self.getAuthMethodsUseCase = getAuthMethodsUseCase
        self.deleteAuthMethodUseCase = deleteAuthMethodsUseCase
        self.authenticationMethods = authenticationMethods
    }

    func deleteAuthMethod(authMethod: AuthenticationMethod) {
        Task {
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid delete:me:authentication_methods")
                try await deleteAuthMethodUseCase.execute(request: DeleteAuthMethodRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: authMethod.id))
                loadData(true)
            } catch {
                await handle(error: error, scope: "openid delete:me:authentication_methods") { [weak self] in
                    self?.deleteAuthMethod(authMethod: authMethod)
                }
            }
        }
    }

    func loadData(_ postDeletion: Bool = false) {
        Task {
            viewAuthenticationMethods = []
            showLoader = true
            errorViewModel = nil
            guard authenticationMethods.isEmpty || postDeletion == true else {
                showLoader = false
                viewAuthenticationMethods = authenticationMethods
                return
            }
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "read:me:authentication_methods")
                let apiAuthMethods = try await getAuthMethodsUseCase.execute(request: GetAuthMethodsRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
                showLoader = false
                let filteredAuthMethods = apiAuthMethods.filter { $0.type == type.rawValue }
                if filteredAuthMethods.isEmpty {
                    NavigationStore.shared.push(type.navigationDestination([]))
                } else {
                    viewAuthenticationMethods = apiAuthMethods.filter { $0.type == type.rawValue }
                }
            } catch {
                await handle(error: error, scope: "read:me:authentication_methods") { [weak self] in
                    self?.loadData(postDeletion)
                }
            }
        }
    }

    var title: String  {
        switch type {
        case .email:
            "Saved Emails for OTP"
        case .sms:
            "Saved Phones for SMS OTP"
        case .totp:
            "Saved Authenticators"
        case .pushNotification:
            "Saved Apps for Push"
        case .recoveryCode:
            "Generated Recovery code"
        }
    }

    var navigationTitle : String {
        switch type {
        case .pushNotification:
            "Push Notification"
        case .totp:
            "Authenticator"
        case .recoveryCode:
            "Recovery Code"
        case .email:
            "Email OTP"
        case .sms:
            "Phone for SMS OTP"
        }
    }

    var confirmationDialogTitle: String {
        switch type {
        case .pushNotification:
            "Push Notification"
        case .totp:
            "Authenticator"
        case .recoveryCode:
            "Recovery Code"
        case .email:
            "Email OTP"
        case .sms:
            "Phone for SMS OTP"
        }
    }

    var confirmationDialogDestructiveButtonTitle: String {
        switch type {
        case .pushNotification:
            "Push Notification"
        case .totp:
            "Authenticator"
        case .recoveryCode:
            "Recovery Code"
        case .email:
            "Email OTP"
        case .sms:
            "Phone for SMS OTP"
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


extension AuthenticationMethod {
    var displayTime: String {
        return ""
    }
}
