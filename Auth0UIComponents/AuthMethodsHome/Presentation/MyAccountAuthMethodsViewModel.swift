
import Combine
import SwiftUI
import Auth0

enum MyAccountAuthViewComponentData: Hashable {
    case title(text: String)

    case subtitle(text: String)

    case createPasskey(model: Any)

    case signinMethods(model: MyAccountAuthMethodViewModel)

    case additionalVerificationMethods(model: MyAccountAuthMethodViewModel)

    case emptyFactors

    static func == (lhs: MyAccountAuthViewComponentData, rhs: MyAccountAuthViewComponentData) -> Bool {
        switch (lhs, rhs) {
        case (.title(let lhsText), .title(let rhsText)):
            return lhsText == rhsText
        case (.subtitle(let lhsText), .subtitle(let rhsText)):
            return lhsText == rhsText
        case (.createPasskey, .createPasskey):
            return true
        case (.signinMethods(let lhsModel), .signinMethods(let rhsModel)):
            return lhsModel == rhsModel
        case (.additionalVerificationMethods(let lhsModel), .additionalVerificationMethods(let rhsModel)):
            return lhsModel == rhsModel
        case (.emptyFactors, .emptyFactors):
            return true
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .title(let text):
            hasher.combine(0)
            hasher.combine(text)
        case .subtitle(let text):
            hasher.combine(1)
            hasher.combine(text)
        case .createPasskey:
            hasher.combine(2)
        case .signinMethods(let model):
            hasher.combine(3)
            hasher.combine(model)
        case .additionalVerificationMethods(let model):
            hasher.combine(4)
            hasher.combine(model)
        case .emptyFactors:
            hasher.combine(5)
        }
    }
}

@MainActor
final class MyAccountAuthMethodsViewModel: ObservableObject {

    private let factorsUseCase: GetFactorsUseCaseable

    private let authMethodsUseCase: GetAuthMethodsUseCaseable

    @Published var viewComponents: [MyAccountAuthViewComponentData] = []

    @Published var errorViewModel: ErrorScreenViewModel? = nil

    @Published var showLoader: Bool = true

    private let dependencies: Auth0UIComponentsSDKInitializer

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
            if self.authMethodsFetched == false {
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
                self.authMethodsFetched = true
            }

            showLoader = false

            let supportedFactors = self.factors.compactMap { AuthMethodType(rawValue: $0.type) }

            var viewComponents: [MyAccountAuthViewComponentData] = []
            if authMethods.filter({ $0.type == "passkey" }).isEmpty == true {
                if #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) {
                    viewComponents.append(.createPasskey(model: PasskeysEnrollmentViewModel(delegate: self)))
                }
            }
            viewComponents.append(.title(text: "Sign-in methods"))
            viewComponents.append(.signinMethods(model: MyAccountAuthMethodViewModel(authMethods: authMethods.filter { $0.type == AuthMethodType.passkey.rawValue }, type: .passkey, dependencies: dependencies)))
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
                // No factors available - show empty state warning
                self.viewComponents = [.emptyFactors]
            }
        } catch  {
            // MARK: Error Handling - Delegate to comprehensive error handler with retry logic
            await handle(error: error, scope: "openid read:me:factors read:me:authentication_methods") { [weak self] in
                Task {
                    // Retry callback: re-execute this method if user taps retry button
                    await self?.loadMyAccountAuthViewComponentData()
                }
            }
        }
    }

    @MainActor func handle(error: Error,
                           scope: String,
                           retryCallback: @escaping () -> Void) async {
        // Hide loading indicator before showing error (unless we're going to reauth)
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
                    
                    dependencies.tokenProvider.store(
                        apiCredentials: APICredentials(from: credentials),
                        for: dependencies.audience
                    )
                    
                    showLoader = false
                    // Retry the original operation with new credentials
                    retryCallback()
                } catch  {
                    // Reauthentication failed - recursively handle the new error
                    await handle(error: error,
                                 scope: scope,
                                 retryCallback: retryCallback)
                }
            } else {
                // Other credential errors - show error screen with retry option
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
    }
    
}
