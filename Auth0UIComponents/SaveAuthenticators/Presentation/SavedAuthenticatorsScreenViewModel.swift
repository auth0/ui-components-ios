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

    func deleteAuthMethod(authMethod: AuthenticationMethod) async {
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "delete:me:authentication_methods")
            try await deleteAuthMethodUseCase.execute(request: DeleteAuthMethodRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: authMethod.id))
            await loadData(true)
        } catch {
            // TODO: show error message here
        }
    }

    func loadData(_ postDeletion: Bool = false) async {
        viewAuthenticationMethods = []
        showLoader = true
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
            showLoader = false
            errorViewModel = ErrorScreenViewModel(title: "Something went wrong", subTitle: "We are unable to process your request. Please try again in a few minutes. If this problem persists, please contact us.", buttonTitle: "Try again", buttonClick: { [weak self] in
                Task {
                    await self?.loadData()
                }
            })
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
}


extension AuthenticationMethod {
    var displayTime: String {
        return ""
    }
}
