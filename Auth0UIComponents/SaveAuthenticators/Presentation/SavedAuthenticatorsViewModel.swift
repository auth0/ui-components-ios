import Auth0
import Combine
import Foundation

/// View model for managing saved authenticators of a specific type.
///
/// Manages the display and deletion of previously enrolled authentication methods
/// for a specific type (email, SMS, TOTP, etc.). Allows users to remove authenticators
/// they no longer need.
@MainActor
final class SavedAuthenticatorsViewModel: ObservableObject, ErrorViewModelHandler {
    private let dependencies: Auth0UIComponentsSDKInitializer
    private let authenticationMethods: [AuthenticationMethod]
    let type: AuthMethodType
    private let getAuthMethodsUseCase: GetAuthMethodsUseCaseable
    private let deleteAuthMethodUseCase: DeleteAuthMethodUseCaseable
    private weak var delegate: RefreshAuthDataProtocol?
    private let errorHandler = ErrorHandler()
    @Published var showManageAuthSheet: Bool = false
    @Published var showLoader: Bool = true
    @Published var errorViewModel: ErrorScreenViewModel? = nil
    @Published var viewAuthenticationMethods: [AuthenticationMethod] = []
    init(dependencies: Auth0UIComponentsSDKInitializer = .shared,
         getAuthMethodsUseCase: GetAuthMethodsUseCaseable = GetAuthMethodsUseCase(),
         deleteAuthMethodsUseCase: DeleteAuthMethodUseCaseable = DeleteAuthMethodUseCase(),
         type: AuthMethodType,
         authenticationMethods: [AuthenticationMethod],
         delegate: RefreshAuthDataProtocol?) {
        self.dependencies = dependencies
        self.type = type
        self.getAuthMethodsUseCase = getAuthMethodsUseCase
        self.deleteAuthMethodUseCase = deleteAuthMethodsUseCase
        self.authenticationMethods = authenticationMethods
        self.delegate = delegate
    }

    func deleteAuthMethod(authMethod: AuthenticationMethod) async {
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid delete:me:authentication_methods")
            try await deleteAuthMethodUseCase.execute(request: DeleteAuthMethodRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: authMethod.id))
            delegate?.refreshAuthData()
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
            viewAuthenticationMethods = authenticationMethods.filter {
                if type == .passkey {
                    $0.type == type.rawValue
                } else {
                    $0.type == type.rawValue && $0.confirmed == true
                }
            }
            return
        }
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid read:me:authentication_methods")
            let apiAuthMethods = try await getAuthMethodsUseCase.execute(request: GetAuthMethodsRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
            self.showLoader = false
            let filteredAuthMethods = apiAuthMethods
                .filter {
                    if type == .passkey {
                        $0.type == type.rawValue
                    } else {
                        $0.type == type.rawValue && $0.confirmed == true
                    }
                }
            if filteredAuthMethods.isEmpty {
                viewAuthenticationMethods = []
            } else {
                viewAuthenticationMethods = filteredAuthMethods
            }
        } catch {
            await handle(error: error, scope: "openid read:me:authentication_methods") { [weak self] in
                Task {
                    await self?.loadData(postDeletion)
                }
            }
        }
    }

    func handle(error: Error, scope: String, retryCallback: @escaping () -> Void) async {
        await errorHandler.handle(error: error, scope: scope, handler: self, retryCallback: retryCallback)
    }
}

extension AuthenticationMethod {
    var formatIsoDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "M/dd/yy"

        if let date = formatter.date(from: createdAt) {
            return outputFormatter.string(from: date)
        }

        let fallbackFormatter = ISO8601DateFormatter()
        fallbackFormatter.formatOptions = [.withInternetDateTime]

        if let date = fallbackFormatter.date(from: createdAt) {
            return outputFormatter.string(from: date)
        }

        return String(createdAt.prefix(10))
    }
}
