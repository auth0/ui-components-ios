import Combine
import Foundation

/// Drives the Email OTP flow, then Guardian push when the tenant asks for a second factor:
/// `LoginEvent`s in, `LoginStep`s out. UI-agnostic.
@MainActor
final class LoginFlowCoordinator: ObservableObject {

    @Published private(set) var step: LoginStep = .loading
    /// A recoverable failure, shown inline on the current input screen.
    @Published private(set) var inputError: AuthFailure?
    /// True while an email submit, resend or verify is in flight. Blocks re-entry and Back.
    @Published private(set) var isSubmitting = false
    /// Runs the second factor while `step == .guardianPush`.
    @Published private(set) var pushController: GuardianPushApprovalController<Void>?
    /// True from Back on the push screen until the check in flight settles. Blocks Back: leaving now would
    /// orphan an approval that is already on its way.
    @Published private(set) var isDrainingPush = false
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

    /// Waits between push checks; injected so tests don't wait.
    private let pushSleep: (Int) async throws -> Void

    init(interactor: AuthInteracting,
         pushSleep: @escaping (Int) async throws -> Void = GuardianPushPollingPolicy.sleep(milliseconds:)) {
        self.interactor = interactor
        self.pushSleep = pushSleep
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

    /// Code entry steps back to email entry. From push: back to the device list when there is one, else a
    /// fresh sign-in at email entry, since the email code is spent. Anywhere else leaves the flow.
    @discardableResult
    func goBack() -> BackOutcome {
        // Leaving now would orphan the in-flight result (e.g. credentials stored, no callback).
        if isSubmitting || isDrainingPush { return .ignored }
        inputError = nil
        switch step {
        case .collectOTPCode, .secondFactorUnavailable:
            step = .collectOTPIdentifier
            return .movedBack
        case .guardianPush:
            if let pushController, pushController.canChooseAnotherDevice {
                pushController.chooseAnotherDevice()
                return .movedBack
            }
            // Stopped now; a check still in flight may yet sign the user in.
            pushController?.cancel()
            step = .collectOTPIdentifier
            drainPush()
            return .movedBack
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
        await endPush()
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
        await endPush()
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
            case let .guardianPush(devices):
                startPush(devices: devices)
            case .secondFactorUnavailable:
                step = .secondFactorUnavailable
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

    // MARK: Guardian push

    private func startPush(devices: [GuardianPushDevice]) {
        let controller = GuardianPushApprovalController(client: interactor.makeGuardianPushClient(),
                                                        devices: devices, policy: .default, sleep: pushSleep) { [weak self] _ in
            self?.step = .authenticated
        }
        pushController = controller
        step = .guardianPush
        controller.start()
    }

    /// Waits, after Back, for a check still in flight; an approval it brings signs the user in.
    private func drainPush() {
        guard let pushController else { return }
        isDrainingPush = true
        Task { [weak self] in
            await pushController.stop()
            self?.isDrainingPush = false
        }
    }

    /// Stops push and waits for a check still in flight: the SDK allows one request at a time.
    private func endPush() async {
        guard let pushController else { return }
        await pushController.stop()
        self.pushController = nil
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
