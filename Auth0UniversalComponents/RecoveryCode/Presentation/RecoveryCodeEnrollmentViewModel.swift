import Combine
import Foundation
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
    private let dependencies: Auth0UniversalComponentsSDKInitializer
    private weak var delegate: RefreshAuthDataProtocol?
    private let errorHandler = ErrorHandler()
    @Published var showLoader: Bool = true
    @Published var errorViewModel: ErrorScreenViewModel?
    @Published var recoveryCodeChallenge: RecoveryCodeEnrollmentChallenge?
    @Published var apiCallInProgress: Bool = false
    @Published var toast: Toast?
    @Published var navigationRoute: Route?

    init(
        startRecoveryCodeEnrollmentUseCase: StartRecoveryCodeEnrollmentUseCaseable = StartRecoveryCodeEnrollmentUseCase(),
        confirmRecoveryCodeEnrollmentUseCase: ConfirmRecoveryCodeEnrollmentUseCaseable = ConfirmRecoveryCodeEnrollmentUseCase(),
        dependencies: Auth0UniversalComponentsSDKInitializer = .shared,
        delegate: RefreshAuthDataProtocol?
    ) {
        self.startRecoveryCodeEnrollmentUseCase = startRecoveryCodeEnrollmentUseCase
        self.confirmRecoveryCodeEnrollmentUseCase = confirmRecoveryCodeEnrollmentUseCase
        self.dependencies = dependencies
        self.delegate = delegate
    }

    func loadData() async {
        showLoader = true
        errorViewModel = nil
        TelemetryManager.shared.trackScreenView("recovery_code")
        TelemetryManager.shared.trackFlow("enrollment_started", factorType: "recovery_code")
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                audience: dependencies.audience,
                scope: "openid create:me:authentication_methods"
            )
            recoveryCodeChallenge = try await startRecoveryCodeEnrollmentUseCase.execute(
                request: StartRecoveryCodeEnrollmentRequest(
                    token: apiCredentials.accessToken,
                    domain: dependencies.domain
                )
            )
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            TelemetryManager.shared.trackApiCall("start_recovery_code_enrollment", durationMs: durationMs, status: .success)
            showLoader = false
        } catch {
            let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            TelemetryManager.shared.trackApiCall("start_recovery_code_enrollment", durationMs: durationMs, status: .failure, errorType: String(describing: type(of: error)))
            TelemetryManager.shared.trackFlow("enrollment_failed", factorType: "recovery_code", status: .failure)
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
            let startTime = CFAbsoluteTimeGetCurrent()
            do {
                let apiCredentials = try await dependencies.tokenProvider.fetchAPICredentials(
                    audience: dependencies.audience,
                    scope: "openid create:me:authentication_methods"
                )
                let confirmRecoveryCodeEnrollmentRequest = ConfirmRecoveryCodeEnrollmentRequest(
                    token: apiCredentials.accessToken,
                    domain: dependencies.domain,
                    id: recoveryCodeChallenge.authenticationId,
                    authSession: recoveryCodeChallenge.authenticationSession
                )
                _ = try await confirmRecoveryCodeEnrollmentUseCase.execute(
                    request: confirmRecoveryCodeEnrollmentRequest
                )
                let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                TelemetryManager.shared.trackApiCall("confirm_recovery_code_enrollment", durationMs: durationMs, status: .success)
                TelemetryManager.shared.trackFlow("enrollment_completed", factorType: "recovery_code", status: .success)
                apiCallInProgress = false
                navigationRoute = .filteredAuthListScreen(type: .recoveryCode, authMethods: [], isPostEnrollment: true)
                delegate?.refreshAuthData()
            } catch {
                let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                TelemetryManager.shared.trackApiCall("confirm_recovery_code_enrollment", durationMs: durationMs, status: .failure, errorType: String(describing: type(of: error)))
                TelemetryManager.shared.trackFlow("enrollment_failed", factorType: "recovery_code", status: .failure)
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
