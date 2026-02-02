import Combine
import Auth0

/// View model for recovery code enrollment.
///
/// Manages the recovery code enrollment process including:
/// - Loading recovery codes from the Auth0 API
/// - Confirming enrollment with the user
/// - Providing codes for secure storage and backup
@MainActor
final class RecoveryCodeEnrollmentViewModel: ObservableObject, ErrorViewModelHandler {

    private let startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable
    private let confirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable
    private let dependencies: Auth0UIComponentsSDKInitializer
    private weak var delegate: RefreshAuthDataProtocol?
    private let errorHandler = ErrorHandler()
    @Published var showLoader: Bool = true
    @Published var errorViewModel: ErrorScreenViewModel?
    @Published var recoveryCodeChallenge: RecoveryCodeEnrollmentChallenge?
    @Published var apiCallInProgress: Bool = false
    @Published var toast: Toast? = nil

    init(startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable = StartRecoveryCodeEnrollmentUseCase(),
         confirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable = ConfirmRecoveryCodeEnrollmentUseCase(),
         dependencies: Auth0UIComponentsSDKInitializer = .shared,
         delegate: RefreshAuthDataProtocol?) {
        self.startRecoveryCodeEnrollmentUseCase = startRecoveryCodeEnrollmentUseCase
        self.confirmRecoveryCodeEnrollmentUseCase = confirmRecoveryCodeEnrollmentUseCase
        self.dependencies = dependencies
        self.delegate = delegate
    }

    func loadData() async {
        showLoader = true
        errorViewModel = nil
        do  {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
            recoveryCodeChallenge = try await startRecoveryCodeEnrollmentUseCase.execute(request: StartRecoveryCodeEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
            showLoader = false
        } catch {
            await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                Task {
                    await self?.loadData()
                }
            }
        }
    }

    func confirmEnrollment() async {
        apiCallInProgress = true
        if let recoveryCodeChallenge {
            do  {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                let confirmRecoveryCodeEnrollmentRequest = ConfirmRecoveryCodeEnrollmentRequest(token: apiCredentials.accessToken,
                                                                                                domain: dependencies.domain,
                                                                                                id: recoveryCodeChallenge.authenticationId,
                                                                                                authSession: recoveryCodeChallenge.authenticationSession)
                let _ = try await confirmRecoveryCodeEnrollmentUseCase.execute(request: confirmRecoveryCodeEnrollmentRequest)
                apiCallInProgress = false
                await NavigationStore.shared.push(.filteredAuthListScreen(type: .recoveryCode, authMethods: []))
                delegate?.refreshAuthData()
            } catch {
                apiCallInProgress = false
                await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                    Task {
                        await self?.confirmEnrollment()
                    }
                }
            }
        }
    }

    func handle(error: Error, scope: String, retryCallback: @escaping () -> Void) async {
        await errorHandler.handle(error: error, scope: scope, handler: self, retryCallback: retryCallback)
    }
}

