import Foundation

/// Runs one recovery code from "typed" to "verified": the check, the new code to save, and its confirmation.
@MainActor
final class RecoveryCodeSession: MfaFactorSession {
    private var state = RecoveryCodeState()
    private let transport: RecoveryCodeTransport
    private weak var host: MfaFactorHost?
    private var inFlight: Task<Void, Never>?
    /// Set when the flow is over: nothing more is sent or reported.
    private var isStopped = false

    init(transport: RecoveryCodeTransport, host: MfaFactorHost) {
        self.transport = transport
        self.host = host
    }

    var model: (any MfaFactorModel)? {
        RecoveryCodeChallengeModel(
            newCode: state.newCode, isVerifying: state.phase == .verifying || state.phase == .confirming,
            isCodeRejected: state.isCodeRejected, requestError: state.requestError, canSwitch: host?.canSwitch ?? false,
            submit: MfaAction<String> { [weak self] in self?.send(.submit($0)) },
            confirm: MfaAction<Void> { [weak self] in self?.send(.confirm) },
            switchFactor: MfaAction<Void> { [weak self] in self?.host?.switchFactor() },
            cancel: MfaAction<Void> { [weak self] in self?.host?.cancel() })
    }

    func start() { host?.modelDidChange() }
    func deactivate() { send(.deactivate) }
    func appBecameActive() {}
    func appBecameInactive() {}

    func cancelAndWait() async {
        isStopped = true
        await inFlight?.value
    }

    private var isWanted: Bool { !isStopped && state.isActive }

    private func send(_ event: RecoveryCodeEvent) {
        guard !isStopped else { return }
        let (next, effects) = RecoveryCodeMachine.reduce(state, event)
        state = next
        effects.forEach(run)
        host?.modelDidChange()
    }

    private func run(_ effect: RecoveryCodeEffect) {
        switch effect {
        case let .verify(code):
            request { session in
                .verified(try await session.transport.verify(code: code, while: { session.isWanted }))
            }
        case .confirm:
            request { session in .confirmed(try await session.transport.confirm(while: { session.isWanted })) }
        case let .report(report):
            switch report {
            case .completed: host?.completed()
            case let .anotherFactor(offers): host?.needsAnotherFactor(offers)
            case let .failed(error): host?.failed(error)
            }
        }
    }

    /// Cancelling a Task doesn't cancel its HTTP call, so `cancelAndWait` waits for this one.
    private func request(_ call: @escaping (RecoveryCodeSession) async throws -> RecoveryCodeEvent) {
        inFlight = Task { [weak self] in
            guard let self, isWanted else { return }
            do {
                send(try await call(self))
            } catch is CancellationError {
                return                                       // the user left while it waited for its turn
            } catch {
                send(.failed(.from(error)))
            }
        }
    }
}
