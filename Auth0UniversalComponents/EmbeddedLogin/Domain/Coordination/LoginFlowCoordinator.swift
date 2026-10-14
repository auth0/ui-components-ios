import Combine
import Foundation

/// Drives the Email OTP flow: `LoginEvent`s in, `LoginStep`s out. UI-agnostic.
@MainActor
final class LoginFlowCoordinator: ObservableObject {

    @Published private(set) var step: LoginStep = .loading
    /// A recoverable failure, shown inline on the current input screen.
    @Published private(set) var inputError: AuthFailure?
    /// True while an email submit, resend or verify is in flight. Blocks re-entry and Back.
    @Published private(set) var isSubmitting = false

    enum BackOutcome { case movedBack, exitFlow, ignored }

    private let interactor: AuthInteracting

    // Outputs of earlier calls that later calls need.
    private var connection: String?
    private var email: String?
    /// Where `retry` returns to; `nil` re-runs discovery.
    private var retryStep: LoginStep?

    init(interactor: AuthInteracting) {
        self.interactor = interactor
    }

    func send(_ event: LoginEvent) async {
        switch event {
        case .start:
            await discover()
        case let .submitIdentifier(email):
            await sendCode(to: email)
        case let .submitOTP(code):
            await verify(code)
        case .retry:
            await retry()
        }
    }

    /// Code entry steps back to email entry; anywhere else leaves the flow.
    @discardableResult
    func goBack() -> BackOutcome {
        // Leaving now would orphan the in-flight result (e.g. credentials stored, no callback).
        if isSubmitting { return .ignored }
        inputError = nil
        guard case .collectOTPCode = step else { return .exitFlow }
        step = .collectOTPIdentifier
        return .movedBack
    }

    func resendOTP() async {
        guard let email else { return }
        inputError = nil
        await sendCode(to: email)
    }

    // MARK: Steps

    private func discover() async {
        step = .loading
        do {
            let options = try await interactor.discover()
            connection = options.lazy.compactMap { option -> String? in
                if case let .emailOTP(connection) = option { return connection }
                return nil
            }.first
            step = connection == nil ? .noMethodsAvailable : .collectOTPIdentifier
        } catch {
            fail(error, returningTo: nil)
        }
    }

    private func sendCode(to email: String) async {
        guard let connection, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        inputError = nil
        step = .loading
        do {
            try await interactor.startOTP(connection: connection, email: email)
            self.email = email
            step = .collectOTPCode(identifier: email)
        } catch let failure as AuthFailure {
            inputError = failure
            step = .collectOTPIdentifier
        } catch {
            fail(error, returningTo: .collectOTPIdentifier)
        }
    }

    /// A rejected code stays on code entry with an inline error.
    private func verify(_ code: String) async {
        guard let email, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        let codeStep = LoginStep.collectOTPCode(identifier: email)
        inputError = nil
        step = .loading
        do {
            try await interactor.verifyOTP(code: code)
            step = .authenticated
        } catch let failure as AuthFailure {
            inputError = failure
            step = codeStep
        } catch let error as CredentialsNotSavedError {
            // The code was consumed and the loop closed, so retry starts a fresh one.
            fail(error, returningTo: .collectOTPIdentifier)
        } catch {
            fail(error, returningTo: codeStep)
        }
    }

    private func fail(_ error: Error, returningTo step: LoginStep?) {
        retryStep = step
        let message = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Please try again."
        self.step = .failed(message: message)
    }

    private func retry() async {
        guard case .failed = step else { return }
        if let retryStep {
            self.retryStep = nil
            step = retryStep
        } else {
            await discover()
        }
    }
}
