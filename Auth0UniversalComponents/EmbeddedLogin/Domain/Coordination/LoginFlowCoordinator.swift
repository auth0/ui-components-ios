import Combine
import Foundation

/// Drives the Email and SMS OTP and password flows, then hands over to an additional step when the tenant asks for
/// more: `LoginEvent`s in, `LoginStep`s out. UI-agnostic. It knows nothing about what the additional step is.
@MainActor
final class LoginFlowCoordinator: ObservableObject {

    @Published private(set) var step: LoginStep = .loading
    /// A recoverable failure, shown inline on the current input screen.
    @Published private(set) var inputError: AuthFailure?
    /// True while an identifier submit, resend or verify is in flight. Blocks re-entry and Back.
    @Published private(set) var isSubmitting = false
    /// Runs the additional step while `step == .additionalStep`. Kept after it ends until the request it had in flight
    /// settles, because the SDK allows one request at a time.
    @Published private(set) var additionalStep: AdditionalStepSession?
    /// The sign-in methods the tenant offers, in its order. The first is the starting screen.
    @Published private(set) var channels: [LoginChannel] = []
    /// What the user last submitted. Pre-fills its screen when the user comes back to it.
    private(set) var enteredIdentifier: LoginIdentifier?

    /// The last code asked for, and when another may be: a code asked for from the password screen waits as long as
    /// Resend does, so switching between the two can't send one on every tap.
    private struct SentCode: Equatable {
        let identifier: LoginIdentifier
        let availableAgainAt: Date
    }

    enum BackOutcome { case movedBack, exitFlow, ignored }

    private let interactor: AuthInteracting

    // Outputs of earlier calls that later calls need.
    private var connection: String?
    /// What the server offered for the last email, number or username submitted. A code asked for again is offered the
    /// password only if it did.
    private var offer: IdentifierOutcome?
    @Published private var sentCode: SentCode?
    /// Where `retry` returns to; `nil` re-runs discovery.
    private var retryStep: LoginStep?

    /// What runs after the first factor. Without one, a tenant that asks for more can't be served.
    private let additionalStepProvider: AdditionalStepProviding?
    private let now: @MainActor () -> Date

    init(interactor: AuthInteracting, additionalStep: AdditionalStepProviding? = nil,
         now: @escaping @MainActor () -> Date = { Date() }) {
        self.interactor = interactor
        self.additionalStepProvider = additionalStep
        self.now = now
    }

    func send(_ event: LoginEvent) async {
        switch event {
        case .start:
            await discover()
        case let .submitIdentifier(identifier):
            await submit(identifier)
        case let .chooseChannel(channel):
            choose(channel)
        case let .submitOTP(code):
            await verify(code)
        case let .submitPassword(password):
            await verifyPassword(password)
        case .sendCodeInstead:
            await sendCodeInstead()
        case .usePasswordInstead:
            await usePasswordInstead()
        case .retry:
            await retry()
        case .restart:
            await restart()
        }
    }

    /// Code or password entry steps back to the screen the identifier was typed on, and that screen back to the first
    /// one. From the additional step, Back cancels it: a fresh sign-in at the first screen, since the code is spent.
    /// Anywhere else leaves the flow.
    @discardableResult
    func goBack() -> BackOutcome {
        // Leaving now would orphan the in-flight result (e.g. credentials stored, no callback).
        if isSubmitting { return .ignored }
        inputError = nil
        switch step {
        case let .collectOTPIdentifier(channel) where channel != primaryChannel:
            step = .collectOTPIdentifier(primaryChannel)
            return .movedBack
        case let .collectOTPCode(identifier, _, _), let .collectPassword(identifier, _):
            step = .collectOTPIdentifier(identifier.channel)
            return .movedBack
        case .additionalStepUnavailable:
            step = .collectOTPIdentifier(primaryChannel)
            return .movedBack
        case .additionalStep:
            // Over: an error screen, or no screen at all. Nothing left to cancel, but the step is told it was left.
            guard let additionalStep, !additionalStep.isFinished else {
                self.additionalStep?.cancel()
                step = .collectOTPIdentifier(primaryChannel)
                return .movedBack
            }
            // The login moves to the first screen once the additional step reports the cancel. While it is storing an
            // approved sign-in it ignores the cancel, and so do we.
            additionalStep.cancel()
            return step == .additionalStep ? .ignored : .movedBack
        default:
            return .exitFlow
        }
    }

    /// Sends the code on the code screen again.
    func resendOTP() async {
        guard case let .collectOTPCode(identifier, _, _) = step else { return }
        inputError = nil
        await requestCode(for: identifier)
    }

    /// The tenant's first method: the screen the sign-in starts on.
    var primaryChannel: LoginChannel { channels.first ?? .email }

    /// When a code may be asked for again for `identifier`; `nil` when none was sent to them.
    func codeAvailableAt(for identifier: LoginIdentifier?) -> Date? {
        guard let sentCode, sentCode.identifier == identifier else { return nil }
        return sentCode.availableAgainAt
    }

    // MARK: Steps

    private func discover() async {
        await endAdditionalStep()
        // A check in flight may have completed the sign-in.
        if step == .authenticated { return }
        step = .loading
        do {
            let options = try await interactor.discover()
            var connection: String?
            var channels: [LoginChannel] = []
            for option in options {
                let offered: (connection: String, channel: LoginChannel)
                switch option {
                case let .emailOTP(value): offered = (value, .email)
                case let .phoneOTP(value): offered = (value, .phone)
                case let .password(value): offered = (value, .password)
                case .unsupported: continue
                }
                connection = connection ?? offered.connection
                if !channels.contains(offered.channel) { channels.append(offered.channel) }
            }
            self.connection = connection
            self.channels = channels
            step = connection == nil ? .noMethodsAvailable : .collectOTPIdentifier(primaryChannel)
        } catch {
            fail(error, returningTo: nil)
        }
    }

    /// "Continue with Phone" (or Password) on the first screen opens that method's own screen.
    private func choose(_ channel: LoginChannel) {
        guard case .collectOTPIdentifier = step, channels.contains(channel), !isSubmitting else { return }
        inputError = nil
        step = .collectOTPIdentifier(channel)
    }

    /// Submits who the user is, then follows what the server lists first: a code is sent at once, or the password is
    /// asked for. The other, when offered, is the alternative on that screen.
    private func submit(_ identifier: LoginIdentifier) async {
        await request(for: identifier) { connection in
            let outcome = try await self.identify(identifier, connection: connection)
            switch outcome {
            case let .passwordOffered(canSendCode):
                return .collectPassword(identifier: identifier, canSendCode: canSendCode)
            case let .codeOffered(canUsePassword):
                return try await self.sendCode(to: identifier, connection: connection, canUsePassword: canUsePassword)
            }
        }
    }

    /// Sends a code again to someone the sign-in already knows, offering the password if the server did.
    private func requestCode(for identifier: LoginIdentifier) async {
        await request(for: identifier) { connection in
            try await self.sendCode(to: identifier, connection: connection,
                                    canUsePassword: self.offer?.offersPassword ?? false)
        }
    }

    /// "Email me a code": the password screen's other way in. It waits as long as Resend does after a code was sent.
    private func sendCodeInstead() async {
        guard case let .collectPassword(identifier, canSendCode) = step, canSendCode,
              codeAvailableAt(for: identifier).map({ $0 <= now() }) ?? true else { return }
        await requestCode(for: identifier)
    }

    /// "Continue with a password": the code screen's other way in. The sign-in is opened again, so the password is
    /// asked for on a session the server still offers it on; the code that was sent goes with the old one.
    private func usePasswordInstead() async {
        guard case let .collectOTPCode(identifier, _, canUsePassword) = step, canUsePassword else { return }
        await request(for: identifier) { connection in
            let outcome = try await self.identify(identifier, connection: connection)
            guard outcome.offersPassword else { throw AuthFailure.passwordNotAvailable }
            return .collectPassword(identifier: identifier, canSendCode: outcome.offersCode)
        }
    }

    /// A request made for `identifier` from the screen the user is on: it shows progress, `work` says which screen
    /// follows, and a failure goes back to the email, number or username screen.
    private func request(for identifier: LoginIdentifier, _ work: (String) async throws -> LoginStep) async {
        guard let connection, !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        enteredIdentifier = identifier
        await endAdditionalStep()
        // A check in flight may have completed the sign-in.
        if step == .authenticated { return }
        inputError = nil
        step = .loading
        do {
            step = try await work(connection)
        } catch let failure as AuthFailure {
            inputError = failure
            step = .collectOTPIdentifier(identifier.channel)
        } catch {
            fail(error, returningTo: .collectOTPIdentifier(identifier.channel))
        }
    }

    private func identify(_ identifier: LoginIdentifier, connection: String) async throws -> IdentifierOutcome {
        let outcome = try await interactor.identify(connection: connection, identifier: identifier)
        offer = outcome
        return outcome
    }

    private func sendCode(to identifier: LoginIdentifier, connection: String,
                          canUsePassword: Bool) async throws -> LoginStep {
        let sentTo = try await interactor.startOTP(connection: connection, identifier: identifier)
        sentCode = SentCode(identifier: identifier,
                            availableAgainAt: now().addingTimeInterval(TimeInterval(ResendCooldown.defaultSeconds)))
        return .collectOTPCode(identifier: identifier, sentTo: sentTo, canUsePassword: canUsePassword)
    }

    /// A rejected code stays on code entry with an inline error.
    private func verify(_ code: String) async {
        guard case let .collectOTPCode(identifier, _, _) = step else { return }
        await settle(identifier, returningTo: step) {
            try await interactor.verifyOTP(code: code)
        }
    }

    /// A rejected password stays on password entry with an inline error.
    private func verifyPassword(_ password: String) async {
        guard case let .collectPassword(identifier, _) = step else { return }
        await settle(identifier, returningTo: step) {
            try await interactor.verifyPassword(password)
        }
    }

    /// Runs one attempt to finish the first factor from `inputStep`, the screen the user is on.
    private func settle(_ identifier: LoginIdentifier, returningTo inputStep: LoginStep,
                        _ attempt: () async throws -> AuthProgress) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        inputError = nil
        step = .loading
        do {
            switch try await attempt() {
            case .authenticated:
                step = .authenticated
            case let .additionalStepRequired(context):
                startAdditionalStep(context)
            }
        } catch let failure as AuthFailure {
            inputError = failure
            step = inputStep
        } catch let error as CredentialsNotSavedError {
            // The code or password was consumed and the loop closed, so retry starts a fresh one.
            fail(error, returningTo: .collectOTPIdentifier(identifier.channel))
        } catch {
            fail(error, returningTo: inputStep)
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
            step = .collectOTPIdentifier(primaryChannel)        // the first screen; the code is spent
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
