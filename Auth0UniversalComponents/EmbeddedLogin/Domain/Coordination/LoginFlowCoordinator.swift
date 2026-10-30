import Combine
import Foundation

/// Drives the Email OTP flow, then hands over to an additional step when the tenant asks for more:
/// `LoginEvent`s in, `LoginStep`s out. UI-agnostic. It knows nothing about what the additional step is.
@MainActor
final class LoginFlowCoordinator: ObservableObject {

    @Published private(set) var step: LoginStep = .loading
    /// A recoverable failure, shown inline on the current input screen.
    @Published private(set) var inputError: AuthFailure?
    /// True while an email submit, resend or verify is in flight. Blocks re-entry and Back.
    @Published private(set) var isSubmitting = false
    /// Runs the additional step while `step == .additionalStep`. Kept after it ends until the request it had in flight
    /// settles, because the SDK allows one request at a time.
    @Published private(set) var additionalStep: AdditionalStepSession?
    /// The email last submitted. Pre-fills email entry when the user comes back to it.
    private(set) var enteredEmail: String?

    enum BackOutcome { case movedBack, exitFlow, ignored }

    private let interactor: AuthInteracting

    // Outputs of earlier calls that later calls need.
    private var connection: String?
    /// The email the code was sent to.
    private var email: String?
    /// Where `retry` returns to; `nil` re-runs discovery.
    private var retryStep: LoginStep?

    /// What runs after the first factor. Without one, a tenant that asks for more can't be served.
    private let additionalStepProvider: AdditionalStepProviding?

    init(interactor: AuthInteracting, additionalStep: AdditionalStepProviding? = nil) {
        self.interactor = interactor
        self.additionalStepProvider = additionalStep
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
        case .restart:
            await restart()
        }
    }

    /// Code entry steps back to email entry. From the additional step, Back cancels it: a fresh sign-in at email entry,
    /// since the email code is spent. Anywhere else leaves the flow.
    @discardableResult
    func goBack() -> BackOutcome {
        // Leaving now would orphan the in-flight result (e.g. credentials stored, no callback).
        if isSubmitting { return .ignored }
        inputError = nil
        switch step {
        case .collectOTPCode, .additionalStepUnavailable:
            step = .collectOTPIdentifier
            return .movedBack
        case .additionalStep:
            // Over: an error screen, or no screen at all. Nothing left to cancel, but the step is told it was left.
            guard let additionalStep, !additionalStep.isFinished else {
                self.additionalStep?.cancel()
                step = .collectOTPIdentifier
                return .movedBack
            }
            // The login moves to email entry once the additional step reports the cancel. While it is storing an
            // approved sign-in it ignores the cancel, and so do we.
            additionalStep.cancel()
            return step == .additionalStep ? .ignored : .movedBack
        default:
            return .exitFlow
        }
    }

    func resendOTP() async {
        guard let email else { return }
        inputError = nil
        await sendCode(to: email)
    }

    // MARK: Steps

    private func discover() async {
        await endAdditionalStep()
        // A check in flight may have completed the sign-in.
        if step == .authenticated { return }
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
        enteredEmail = email
        await endAdditionalStep()
        // A check in flight may have completed the sign-in.
        if step == .authenticated { return }
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
            switch try await interactor.verifyOTP(code: code) {
            case .authenticated:
                step = .authenticated
            case let .additionalStepRequired(context):
                startAdditionalStep(context)
            }
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

    // MARK: Additional step

    private func startAdditionalStep(_ context: AdditionalStepContext) {
        guard let additionalStepProvider else {
            step = .additionalStepUnavailable
            return
        }
        let session = additionalStepProvider.makeSession(context: context, delegate: self)
        additionalStep = session
        step = .additionalStep
        session.start()
    }

    /// Ends the additional step, if it is still going, and waits for a request still in flight: the SDK allows one at a
    /// time, and a reply that arrives after it ended is dropped.
    private func endAdditionalStep() async {
        guard let additionalStep else { return }
        await additionalStep.cancelAndWait()
        self.additionalStep = nil
    }

    private func restart() async {
        guard !isSubmitting else { return }
        inputError = nil
        retryStep = nil
        await discover()
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

extension LoginFlowCoordinator: AdditionalStepDelegate {
    func additionalStepDidFinish(_ result: AdditionalStepResult) {
        switch result {
        case .completed:
            step = .authenticated
        case .cancelled:
            step = .collectOTPIdentifier                        // the first screen; the email code is spent
        case let .unavailable(reported):
            // If the app was told it routes the user itself. Otherwise say so rather than leave a spinner.
            if !reported { step = .additionalStepUnavailable }
        case .failed:
            break                                               // the additional step shows its own error and way out
        }
    }

    func additionalStepRequestedRestart() {
        Task { await send(.restart) }
    }
}
