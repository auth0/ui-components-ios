import Auth0
@testable import Auth0UniversalComponents
import SwiftUI

// A stand-in for whatever runs the additional step. It is written against the login's own contract only, so the login
// can be tested without anything from MFA.

@MainActor
final class ScriptedAdditionalStepProvider: AdditionalStepProviding {
    private(set) var contexts: [AdditionalStepContext] = []
    private(set) var sessions: [ScriptedAdditionalStepSession] = []

    var last: ScriptedAdditionalStepSession { sessions[sessions.count - 1] }

    func makeSession(context: AdditionalStepContext, delegate: AdditionalStepDelegate) -> AdditionalStepSession {
        contexts.append(context)
        let session = ScriptedAdditionalStepSession(delegate: delegate)
        sessions.append(session)
        return session
    }
}

@MainActor
final class ScriptedAdditionalStepSession: AdditionalStepSession {
    private weak var delegate: AdditionalStepDelegate?
    private(set) var isFinished = false
    private(set) var log: [String] = []
    let view = AnyView(Text("additional step"))
    /// Like a sign-in being stored: it refuses to be cancelled.
    var ignoresCancel = false
    /// Keeps `cancelAndWait` waiting, like a request still on the wire.
    var holdsCancel = false
    private var gate: CheckedContinuation<Void, Never>?

    init(delegate: AdditionalStepDelegate) {
        self.delegate = delegate
    }

    func start() { log.append("start") }

    func cancel() {
        log.append("cancel")
        // A step that already ended reports nothing more, like the real one.
        if !ignoresCancel, !isFinished { finish(.cancelled) }
    }

    func cancelAndWait() async {
        log.append("cancelAndWait")
        if holdsCancel { await withCheckedContinuation { gate = $0 } }
    }

    func releaseCancel() {
        gate?.resume()
        gate = nil
    }

    func finish(_ result: AdditionalStepResult) {
        isFinished = true
        delegate?.additionalStepDidFinish(result)
    }

    func requestRestart() { delegate?.additionalStepRequestedRestart() }
}

extension AdditionalStepContext {
    @MainActor
    static func sample(nextActions: [NextAction] = [], client: EmbeddedAuthClient? = nil,
                       store: CredentialsStoring? = nil) -> AdditionalStepContext {
        AdditionalStepContext(nextActions: nextActions, client: client ?? StubEmbeddedAuthClient(),
                              credentialsStore: store ?? StubCredentialsStore())
    }
}

/// Records how a step reports back to the login.
@MainActor
final class RecordingAdditionalStepDelegate: AdditionalStepDelegate {
    private(set) var results: [AdditionalStepResult] = []
    private(set) var restarts = 0
    func additionalStepDidFinish(_ result: AdditionalStepResult) { results.append(result) }
    func additionalStepRequestedRestart() { restarts += 1 }
}
