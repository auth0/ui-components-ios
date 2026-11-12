import Foundation

/// Runs the authenticator app factor from "enter the code" to "verified": one code check at a time. It owns everything
/// about the code; the Core only hears the result.
@MainActor
final class TotpSession: MfaFactorSession {
    private var state = TotpState()
    private let transport: TotpTransport
    private weak var host: MfaFactorHost?
    private var inFlight: Task<Void, Never>?
    /// Set when the flow is over: nothing more is reported or sent.
    private var isStopped = false

    init(transport: TotpTransport, host: MfaFactorHost) {
        self.transport = transport
        self.host = host
    }

    var model: (any MfaFactorModel)? {
        guard state.phase == .awaitingCode || state.phase == .verifying else { return nil }
        return TotpChallengeModel(
            codeLength: TotpMachine.codeLength, isVerifying: state.phase == .verifying,
            isCodeRejected: state.isCodeRejected, requestError: state.requestError,
            canSwitch: host?.canSwitch ?? false,
            submit: MfaAction<String> { [weak self] in self?.send(.submit(code: $0)) },
            switchFactor: MfaAction<Void> { [weak self] in self?.host?.switchFactor() },
            cancel: MfaAction<Void> { [weak self] in self?.host?.cancel() })
    }

    func start() { send(.start) }
    func deactivate() { send(.deactivate) }

    // Nothing is polled or timed, so the app going away changes nothing.
    func appBecameActive() {}
    func appBecameInactive() {}

    func cancelAndWait() async {
        isStopped = true
        await inFlight?.value
    }

    private func send(_ event: TotpEvent) {
        guard !isStopped else { return }
        let (next, effects) = TotpMachine.reduce(state, event)
        state = next
        effects.forEach(run)
        host?.modelDidChange()
    }

    private func run(_ effect: TotpEffect) {
        switch effect {
        case let .verify(code):
            verify(code)
        case let .report(report):
            switch report {
            case .completed: host?.completed()
            case let .anotherFactor(offers): host?.needsAnotherFactor(offers)
            case let .failed(error): host?.failed(error)
            }
        }
    }

    /// Cancelling a Task doesn't cancel its HTTP call, so `cancelAndWait` waits for this one.
    private func verify(_ code: String) {
        inFlight = Task { [weak self] in
            guard let self, self.isWanted else { return }
            do {
                self.send(.verified(try await self.transport.verify(code: code, while: { self.isWanted })))
            } catch is CancellationError {
                return                                       // the user left while it waited for its turn
            } catch {
                self.send(.verifyFailed(.from(error)))
            }
        }
    }

    private var isWanted: Bool { !isStopped && state.isActive }
}
