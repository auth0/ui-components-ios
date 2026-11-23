import Auth0
import Combine
import Foundation

/// Drives a sign-up: `SignupEvent`s in, `SignupStep`s out. UI-agnostic. The server's menu decides each next screen,
/// never a fixed order, so a second identifier is a new kind and its screens, not a change here.
@MainActor
final class SignupFlowCoordinator: ObservableObject {

    @Published private(set) var step: SignupStep = .loading
    /// A recoverable failure, shown inline on the current input screen.
    @Published private(set) var inputError: SignupFailure?
    /// True while a request is in flight. The screen stays as it is, with progress in its button. Blocks re-entry
    /// and Back.
    @Published private(set) var isSubmitting = false
    /// What the user last submitted. Pre-fills its screen when they come back to it.
    private(set) var entered: SignupIdentifierValue?

    enum BackOutcome { case movedBack, exitFlow, ignored }

    private let interactor: SignupInteracting
    /// Where "Try again" returns to; `nil` opens the sign-up again.
    private var retryStep: SignupStep?
    /// The SDK allows one request at a time, and `.start` runs again whenever the screen reappears.
    private var isOpening = false
    private var hasStarted = false

    init(interactor: SignupInteracting) {
        self.interactor = interactor
    }

    func send(_ event: SignupEvent) async {
        switch event {
        case .start: if !hasStarted { await open() }
        case .restart: await open()
        case let .submitIdentifier(value):
            await request { screen in try await self.identifyAndSendCode(value, from: screen) }
        case let .submitCode(code): await request { screen in try await self.verify(code, from: screen) }
        case .resend: await request { screen in try await self.resend(from: screen) }
        case .confirm: await continueFromVerified()
        case .retry: await retry()
        }
    }

    /// Edit and Back on the code screen return to the entry, with what was typed. Anywhere else leaves the flow: a
    /// verified identifier can't be changed, so there is nothing to go back to.
    @discardableResult
    func goBack() -> BackOutcome {
        if isSubmitting { return .ignored }
        inputError = nil
        switch step {
        case let .collectCode(code):
            step = .collectIdentifier(code.identifier.kind)
            return .movedBack
        default:
            return .exitFlow
        }
    }

    // MARK: Steps

    private func open() async {
        guard !isSubmitting, !isOpening else { return }
        isOpening = true
        hasStarted = true
        defer { isOpening = false }
        inputError = nil
        entered = nil
        retryStep = nil
        step = .loading
        do {
            step = nextStep(after: try await interactor.open())
        } catch is SignupUnavailable {
            step = .unavailable
        } catch let failure as SignupFailure {
            step = .failed(message: failure.message, canRetry: false)
        } catch {
            fail(error, returningTo: nil)
        }
    }

    /// The design sends the code as soon as the identifier is accepted.
    private func identifyAndSendCode(_ value: SignupIdentifierValue,
                                     from screen: SignupStep) async throws -> SignupStep {
        guard case .collectIdentifier = screen else { return screen }
        entered = value
        guard let challenge = try await interactor.identify(value).challenge else { throw SignupFailure.codeNotSent }
        try await interactor.sendCode(challenge)
        return .collectCode(SignupCodeStep(identifier: value, challenge: challenge))
    }

    private func verify(_ code: String, from screen: SignupStep) async throws -> SignupStep {
        guard case .collectCode = screen else { return screen }
        switch try await interactor.verify(code: code) {
        case .authenticated: return .authenticated
        case let .next(menu): return nextStep(after: menu)
        }
    }

    private func resend(from screen: SignupStep) async throws -> SignupStep {
        guard case let .collectCode(code) = screen else { return screen }
        try await interactor.sendCode(code.challenge)
        return screen
    }

    /// Continue on the verified screen creates the account. Only from there: a repeated tap or a late event can't
    /// create it twice.
    private func continueFromVerified() async {
        await request { screen in
            guard case .confirm = screen else { return screen }
            try await self.interactor.confirm()
            return .authenticated
        }
    }

    /// One rule for every menu: the account can be created, or something is still to be entered.
    private func nextStep(after menu: SignupMenu) -> SignupStep {
        if menu.canConfirm { return .confirm }
        if let kind = menu.askedFor.first { return .collectIdentifier(kind) }
        return .failed(message: Self.somethingWentWrong, canRetry: false)
    }

    // MARK: Requests

    /// Runs one request for the screen the user is on. A failure they can fix stays on that screen; one that ends the
    /// sign-up, or any other, goes full screen.
    private func request(_ work: (SignupStep) async throws -> SignupStep) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        inputError = nil
        let screen = step
        do {
            step = try await work(screen)
        } catch let failure as SignupFailure {
            if failure.endsSignup {
                step = .failed(message: failure.message, canRetry: false)
            } else {
                inputError = failure
            }
        } catch let error as CredentialsNotSavedError {
            // The code was used and the sign-in closed: only a new one helps.
            step = .failed(message: error.errorDescription ?? Self.somethingWentWrong, canRetry: false)
        } catch {
            fail(error, returningTo: screen)
        }
    }

    private func fail(_ error: Error, returningTo screen: SignupStep?) {
        retryStep = screen
        step = .failed(message: (error as? LocalizedError)?.errorDescription ?? Self.somethingWentWrong, canRetry: true)
    }

    private func retry() async {
        guard case .failed(_, true) = step else { return }
        if let retryStep {
            self.retryStep = nil
            step = retryStep
        } else {
            await open()
        }
    }

    private static let somethingWentWrong = "Something went wrong. Please try again."
}
