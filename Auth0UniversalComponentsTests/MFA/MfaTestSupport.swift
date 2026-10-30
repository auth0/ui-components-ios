@testable import Auth0UniversalComponents
import SwiftUI
import Foundation

// Shared doubles for the MFA tests. Nothing here knows about Guardian push or Embedded Login: the Core is exercised
// with generic scripted factors, exactly as any future factor would plug in.

// MARK: Clocks

/// Time only moves when the test says so.
actor ManualMfaClock: MfaClock {
    private var sleepers: [CheckedContinuation<Void, Error>] = []

    func sleep(milliseconds: Int) async throws {
        try await withCheckedThrowingContinuation { sleepers.append($0) }
    }

    /// Waits for a sleeper to register (the poll task runs on its own), then wakes everything asleep.
    func advance() async {
        var waited = 0
        while sleepers.isEmpty && waited < 2_000 {
            try? await Task.sleep(nanoseconds: 1_000_000)
            waited += 1
        }
        let all = sleepers
        sleepers = []
        all.forEach { $0.resume() }
    }
}

/// Records each wait and returns at once, or suspends until cancelled, like a long `Task.sleep`.
@MainActor
final class RecordingMfaClock: MfaClock {
    private(set) var delays: [Int] = []
    var suspends = false

    // `MfaClock.sleep` is nonisolated, so the recording hops to the main actor.
    nonisolated func sleep(milliseconds: Int) async throws {
        if await record(milliseconds) { try await Task.sleep(nanoseconds: .max) }
    }

    /// Returns whether to suspend.
    private func record(_ milliseconds: Int) -> Bool {
        delays.append(milliseconds)
        return suspends
    }
}

/// Lets work that hops between threads (the clock, poll tasks, request chains) finish. Yielding alone is not
/// enough: a wake-up on another thread can take longer than any fixed number of yields.
func settle() async {
    for _ in 0..<4 {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 8_000_000)
    }
}

/// Waits, for up to two seconds, for something that should happen. Prefer it to `settle()` for a positive result: under
/// load (a whole suite running at once) a wake-up on another thread can take longer than any fixed wait.
@MainActor
func eventually(_ condition: () -> Bool) async {
    for _ in 0..<2_000 where !condition() { try? await Task.sleep(nanoseconds: 1_000_000) }
}

// MARK: Committer

@MainActor
final class FakeCommitter: MfaCommitter {
    private(set) var stored = 0
    private(set) var abandoned = false
    var commitFails = false

    func commit() throws {
        if commitFails { throw MfaError.credentialsNotSaved }
        stored += 1
    }

    func abandon() { abandoned = true }
}

/// Collects how the flow ended.
@MainActor
final class FinishLog {
    private(set) var results: [MfaError?] = []
    func record(_ error: MfaError?) { results.append(error) }
}

// MARK: A generic scripted factor

struct ScriptedModel: MfaFactorModel, Equatable {
    let name: String
    let switchFactor: MfaAction<Void>
    let cancel: MfaAction<Void>
}

/// A factor with no behaviour of its own: the test decides when it is ready, completes, fails, or asks for a menu.
@MainActor
final class ScriptedFactor: MfaFactor {
    let id: MfaFactorID
    let rank: Int
    private(set) var sessions: [ScriptedSession] = []

    init(_ id: MfaFactorID, rank: Int = 10) {
        self.id = id
        self.rank = rank
    }

    var last: ScriptedSession { sessions[sessions.count - 1] }

    func row(for offer: MfaFactorOffer, messages: MfaMessages) -> MfaFactorRowContent {
        MfaFactorRowContent(title: offer.label ?? id.rawValue, subtitle: id.rawValue, icon: nil)
    }

    func makeSession(for offer: MfaFactorOffer, host: MfaFactorHost,
                     environment: MfaFactorEnvironment) -> MfaFactorSession {
        let session = ScriptedSession(offer: offer, host: host)
        sessions.append(session)
        return session
    }

    func standardView(for model: any MfaFactorModel, messages: MfaMessages) -> AnyView? {
        (model as? ScriptedModel).map { AnyView(Text($0.name)) }
    }
}

@MainActor
final class ScriptedSession: MfaFactorSession {
    let offer: MfaFactorOffer
    private weak var host: MfaFactorHost?
    private(set) var model: (any MfaFactorModel)?
    private(set) var log: [String] = []
    /// Holds `cancelAndWait` until released, like a request still on the wire.
    var holdsCancel = false
    private var gate: CheckedContinuation<Void, Never>?

    init(offer: MfaFactorOffer, host: MfaFactorHost) {
        self.offer = offer
        self.host = host
    }

    func start() { log.append("start") }
    func deactivate() { log.append("deactivate") }
    func appBecameActive() { log.append("active") }
    func appBecameInactive() { log.append("inactive") }

    func cancelAndWait() async {
        log.append("cancelAndWait")
        if holdsCancel { await withCheckedContinuation { gate = $0 } }
    }

    func releaseCancel() {
        gate?.resume()
        gate = nil
    }

    // What the test makes the factor do.
    func becomeReady() {
        model = ScriptedModel(name: offer.id,
                              switchFactor: MfaAction<Void> { [weak self] in self?.host?.switchFactor() },
                              cancel: MfaAction<Void> { [weak self] in self?.host?.cancel() })
        host?.modelDidChange()
    }

    func complete() { host?.completed() }
    func fail(_ error: MfaError) { host?.failed(error) }
    func askForMenu(_ offers: [MfaFactorOffer]) { host?.needsAnotherFactor(offers) }
}

func scriptedOffer(_ id: String, factor: MfaFactorID, label: String? = nil) -> MfaFactorOffer {
    MfaFactorOffer(id: id, factor: factor, label: label, reference: nil)
}

extension MfaFactorID {
    static let alpha: MfaFactorID = "alpha"
    static let beta: MfaFactorID = "beta"
}

// MARK: Hosts and registries

@MainActor
func registry(_ factors: ScriptedFactor...) -> MfaFactorRegistry { MfaFactorRegistry(factors) }

/// The Core's side of a session, recorded.
@MainActor
final class FakeHost: MfaFactorHost {
    var canSwitch = false
    private(set) var events: [String] = []
    private(set) var offers: [[MfaFactorOffer]] = []
    private(set) var errors: [MfaError] = []
    private(set) var changes = 0

    func modelDidChange() { changes += 1 }
    func completed() { events.append("completed") }
    func needsAnotherFactor(_ offers: [MfaFactorOffer]) { events.append("menu"); self.offers.append(offers) }
    func failed(_ error: MfaError) { events.append("failed"); errors.append(error) }
    func switchFactor() { events.append("switch") }
    func cancel() { events.append("cancel") }
}

extension MfaFlowEffect {
    var isFinish: Bool { if case .finish = self { return true } else { return false } }
    var isStart: Bool { if case .startSession = self { return true } else { return false } }
}

extension [MfaFlowEffect] {
    var finishCount: Int { filter(\.isFinish).count }
    var startCount: Int { filter(\.isStart).count }
}
