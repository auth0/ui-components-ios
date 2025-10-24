import Combine
import Auth0

@MainActor
final class RecoveryCodeEnrollmentViewModel: ObservableObject {
    
    private let startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable
    private let confirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable
    private let dependencies: Dependencies
    
    @Published var showLoader: Bool = false
    @Published var errorViewModel: ErrorScreenViewModel?
    @Published var recoveryCodeChallenge: RecoveryCodeEnrollmentChallenge?

    init(startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable = StartRecoveryCodeEnrollmentUseCase(),
         confirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable = ConfirmRecoveryCodeEnrollmentUseCase(),
         dependencies: Dependencies = .shared) {
        self.startRecoveryCodeEnrollmentUseCase = startRecoveryCodeEnrollmentUseCase
        self.confirmRecoveryCodeEnrollmentUseCase = confirmRecoveryCodeEnrollmentUseCase
        self.dependencies = dependencies
    }

    func loadData() async {
        showLoader = true
        errorViewModel = nil
        do  {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "create:me:authentication_methods")
            recoveryCodeChallenge = try await startRecoveryCodeEnrollmentUseCase.execute(request: StartRecoveryCodeEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain))
            showLoader = false
        } catch {
            showLoader = false
            errorViewModel = ErrorScreenViewModel(title: "Something went wrong", subTitle: "We are unable to process your request. Please try again in a few minutes. If this problem persists, please contact us.", buttonTitle: "Try again", buttonClick: { [weak self] in
                Task {
                    await self?.loadData()
                }
            })
        }
    }

    func confirmEnrollment() {
        Task {
            if let recoveryCodeChallenge {
                do  {
                    let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(audience: dependencies.audience, scope: "create:me:authentication_methods")
                    let _ = try await confirmRecoveryCodeEnrollmentUseCase.execute(request: ConfirmRecoveryCodeEnrollmentRequest(token: apiCredentials.accessToken, domain: dependencies.domain, id: recoveryCodeChallenge.authenticationId, authSession: recoveryCodeChallenge.authenticationSession))
                    await NavigationStore.shared.push(.filteredAuthListScreen(type: .recoveryCode, authMethods: []))
                } catch {
                    // TODO: error message
                }
            }
        }
    }
}

