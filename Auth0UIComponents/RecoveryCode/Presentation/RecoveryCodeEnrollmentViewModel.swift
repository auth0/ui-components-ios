import Combine
import Auth0

@MainActor
final class RecoveryCodeEnrollmentViewModel: ObservableObject {
    
    private let startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable
    private let confirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable
    private let dependencies: Dependencies
    
    @Published var showLoader: Bool = true
    @Published var errorViewModel: ErrorScreenViewModel?
    @Published var recoveryCodeChallenge: RecoveryCodeEnrollmentChallenge?

    init(startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable = StartRecoveryCodeEnrollmentUseCase(),
         confirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable = ConfirmRecoveryCodeEnrollmentUseCase(),
         dependencies: Dependencies = .shared) {
        self.startRecoveryCodeEnrollmentUseCase = startRecoveryCodeEnrollmentUseCase
        self.confirmRecoveryCodeEnrollmentUseCase = confirmRecoveryCodeEnrollmentUseCase
        self.dependencies = dependencies
    }

    func loadData() {
        Task {
            showLoader = true
            errorViewModel = nil
            do  {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                recoveryCodeChallenge = try await startRecoveryCodeEnrollmentUseCase.execute(request: StartRecoveryCodeEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
                showLoader = false
            } catch {
                await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                    self?.loadData()
                }
            }
        }
    }

    func confirmEnrollment() {
        Task {
            if let recoveryCodeChallenge {
                do  {
                    let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "openid create:me:authentication_methods")
                    let _ = try await confirmRecoveryCodeEnrollmentUseCase.execute(request: ConfirmRecoveryCodeEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: recoveryCodeChallenge.authenticationId, authSession: recoveryCodeChallenge.authenticationSession))
                    await NavigationStore.shared.push(.filteredAuthListScreen(type: .recoveryCode, authMethods: []))
                } catch {
                    await handle(error: error, scope: "openid create:me:authentication_methods") { [weak self] in
                        Task {
                            self?.confirmEnrollment()
                        }
                    }
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

