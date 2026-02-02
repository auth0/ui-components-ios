
import Combine
import SwiftUI
import Auth0

/// Represents a single component to display in the My Account Auth Methods view.
///
/// This enum allows for composable UI components representing different sections
/// of the authentication methods management interface.
enum MyAccountAuthViewComponentData: Hashable {
    /// A heading section with title text
    case title(text: String)
    /// A subtitle or description section
    case subtitle(text: String)
    /// Promotional banner for passkey enrollment
    case createPasskey(model: Any)
    /// A sign-in method card (displayed under "Sign-in Methods")
    case signinMethods(model: MyAccountAuthMethodViewModel)
    /// An additional verification method card (displayed under "Additional Verification")
    case additionalVerificationMethods(model: MyAccountAuthMethodViewModel)
    /// An informational view indicating no factors are configured
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
            let viewModel = MyAccountAuthMethodViewModel(authMethods: authMethods.filter { $0.type == AuthMethodType.passkey.rawValue },
                                                         type: .passkey,
                                                         dependencies: dependencies)
            viewComponents.append(.signinMethods(model: viewModel))
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

                    dependencies.tokenProvider.store(
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
    }
    
}
