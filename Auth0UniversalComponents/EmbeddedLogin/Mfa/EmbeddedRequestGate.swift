import Foundation

/// The SDK allows one request at a time per sign-in. Every factor's transport of one sign-in shares this gate: a
/// session the user switched away from may still have a request on its way (a push check, a code check) when the
/// next factor sends its own.
@MainActor
final class EmbeddedRequestGate {
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    /// The offer whose request went out last: a challenge (a code sent, a push sent) or a code checked. The SDK keeps
    /// one `auth_session` for the whole sign-in and a code names no challenge, so a code is only ever checked against
    /// the last one: sending another challenge, or checking another factor's code, replaces it.
    private(set) var lastChallenge: String?

    /// Runs `call` once no other request of this sign-in is on its way. Waiting calls run in the order they arrived.
    /// `isWanted` is asked again when the turn comes; if it says no, nothing is sent and `CancellationError` is thrown.
    func run<T>(challenging offerID: String? = nil, while isWanted: () -> Bool = { true },
                _ call: () async throws -> T) async throws -> T {
        if isBusy {
            await withCheckedContinuation { waiters.append($0) }    // the finishing request hands its turn over
        } else {
            isBusy = true
        }
        defer {
            if waiters.isEmpty { isBusy = false } else { waiters.removeFirst().resume() }
        }
        guard isWanted() else { throw CancellationError() }
        if let offerID { lastChallenge = offerID }
        return try await call()
    }
}
