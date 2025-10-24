
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
    @Published var showLoader: Bool = false
    private let dependencies: Dependencies

    init (session: URLSession = .shared,
          factorsUseCase: GetFactorsUseCaseable = GetFactorsUseCase(),
          authMethodsUseCase: GetAuthMethodsUseCaseable = GetAuthMethodsUseCase(),
          dependencies: Dependencies = .shared) {
        self.factorsUseCase = factorsUseCase
        self.authMethodsUseCase = authMethodsUseCase
        self.dependencies = dependencies
    }

    func loadMyAccountAuthViewComponentData() async {
        errorViewModel = nil
        self.viewComponents = []
        showLoader = true
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "read:me:factors read:me:authentication_methods")
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
                errorViewModel = ErrorScreenViewModel(title: "Something went wrong", subTitle: "", buttonTitle: "", buttonClick: {
                    
                })
            }
        } catch {
            showLoader = false
            errorViewModel = ErrorScreenViewModel(title: "Something went wrong", subTitle: "We are unable to process your request. Please try again in a few minutes. If this problem persists, please contact us.", buttonTitle: "Try again", buttonClick: { [weak self] in
                Task {
                    await self?.loadMyAccountAuthViewComponentData()
                }
            })
        }
    }
}
