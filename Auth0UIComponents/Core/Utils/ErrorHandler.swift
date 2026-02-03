import Auth0
import Foundation

/// Protocol for ViewModels that handle errors with errorViewModel
protocol ErrorViewModelHandler: AnyObject {
    var showLoader: Bool { get set }
    var errorViewModel: ErrorScreenViewModel? { get set }
}

/// Protocol for ViewModels that handle errors with errorMessage
protocol ErrorMessageHandler: AnyObject {
    var errorMessage: String? { get set }
}

/// Centralized error handler for Auth0 UI Components.
///
/// Handles CredentialsManagerError, MyAccountError, and WebAuthError with appropriate
/// retry logic and user-facing error messages.
@MainActor
struct ErrorHandler {

    private let dependencies: Auth0UIComponentsSDKInitializer

    init(dependencies: Auth0UIComponentsSDKInitializer = .shared) {
        self.dependencies = dependencies
    }

    /// Handles errors for ViewModels using errorViewModel pattern
    ///
    /// - Parameters:
    ///   - error: The error to handle
    ///   - scope: OAuth scope for retry requests
    ///   - handler: The ViewModel conforming to ErrorViewModelHandler
    ///   - retryCallback: Callback to retry the operation
    func handle(
        error: Error,
        scope: String,
        handler: ErrorViewModelHandler,
        retryCallback: @escaping () -> Void
    ) async {
        handler.showLoader = false

        if let error = error as? CredentialsManagerError {
            await handleCredentialsManagerError(
                error,
                scope: scope,
                handler: handler,
                retryCallback: retryCallback
            )
        } else if let error = error as? MyAccountError {
            handleMyAccountError(error, handler: handler, retryCallback: retryCallback)
        } else if let error = error as? WebAuthError {
            handleWebAuthError(error, handler: handler, retryCallback: retryCallback)
        }
    }

    /// Handles errors for ViewModels using errorMessage pattern (OTP flows)
    ///
    /// - Parameters:
    ///   - error: The error to handle
    ///   - scope: OAuth scope for retry requests
    ///   - handler: The ViewModel conforming to ErrorMessageHandler
    ///   - retryCallback: Callback to retry the operation
    func handle(
        error: Error,
        scope: String,
        handler: ErrorMessageHandler,
        retryCallback: @escaping () -> Void
    ) async {
        if let error = error as? CredentialsManagerError {
            await handleCredentialsManagerError(
                error,
                scope: scope,
                handler: handler,
                retryCallback: retryCallback
            )
        } else if let error = error as? MyAccountError {
            handleMyAccountError(error, handler: handler)
        } else if let error = error as? WebAuthError {
            handler.errorMessage = error.message
        }
    }

    // MARK: - Private Helper Methods

    private func handleCredentialsManagerError(
        _ error: CredentialsManagerError,
        scope: String,
        handler: ErrorViewModelHandler,
        retryCallback: @escaping () -> Void
    ) async {
        let uiComponentError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
        if case .mfaRequired = uiComponentError {
            handler.showLoader = true
            do {
                let credentials = try await Auth0.webAuth(
                    clientId: dependencies.clientId,
                    domain: dependencies.domain,
                    session: dependencies.session
                )
                .audience(dependencies.audience)
                .scope(scope)
                .start()
                handler.showLoader = false
                dependencies.tokenProvider.store(
                    apiCredentials: APICredentials(from: credentials),
                    for: dependencies.audience
                )
                retryCallback()
            } catch {
                await handle(
                    error: error,
                    scope: scope,
                    handler: handler,
                    retryCallback: retryCallback
                )
            }
        } else {
            handler.errorViewModel = uiComponentError.errorViewModel(completion: {
                retryCallback()
            })
        }
    }

    private func handleCredentialsManagerError(
        _ error: CredentialsManagerError,
        scope: String,
        handler: ErrorMessageHandler,
        retryCallback: @escaping () -> Void
    ) async {
        let uiComponentError = Auth0UIComponentError.handleCredentialsManagerError(error: error)
        if case .mfaRequired = uiComponentError {
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
                retryCallback()
            } catch {
                await handle(
                    error: error,
                    scope: scope,
                    handler: handler,
                    retryCallback: retryCallback
                )
            }
        } else {
            handler.errorMessage = error.message
        }
    }

    private func handleMyAccountError(
        _ error: MyAccountError,
        handler: ErrorViewModelHandler,
        retryCallback: @escaping () -> Void
    ) {
        let uiComponentError = Auth0UIComponentError.handleMyAccountAuthError(error: error)
        handler.errorViewModel = uiComponentError.errorViewModel(completion: {
            retryCallback()
        })
    }

    private func handleMyAccountError(
        _ error: MyAccountError,
        handler: ErrorMessageHandler
    ) {
        if error.code == "invalid_grant" ||
            error.message.localizedStandardContains("invalid") ||
            error.message.localizedStandardContains("incorrect") {
            handler.errorMessage = "Invalid passcode. Please try again."
        } else if error.message.localizedStandardContains("expired") {
            handler.errorMessage = "Passcode expired. Please request a new one."
        } else if error.message.localizedStandardContains("rate") {
            handler.errorMessage = "Too many attempts. Please try again later."
        } else {
            handler.errorMessage = error.message
        }
    }

    private func handleWebAuthError(
        _ error: WebAuthError,
        handler: ErrorViewModelHandler,
        retryCallback: @escaping () -> Void
    ) {
        let uiComponentError = Auth0UIComponentError.handleWebAuthError(error: error)
        handler.errorViewModel = uiComponentError.errorViewModel {
            retryCallback()
        }
    }
}
