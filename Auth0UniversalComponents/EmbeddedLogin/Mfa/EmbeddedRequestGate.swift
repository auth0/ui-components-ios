import Foundation

/// The SDK allows one request at a time per sign-in. Every factor's transport of one sign-in shares this gate: a
/// session the user switched away from may still have a request on its way (a push check, a code check) when the
/// next factor sends its own.
@MainActor
final class EmbeddedRequestGate {
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Runs `call` once no other request of this sign-in is on its way. Waiting calls run in the order they arrived.
    func run<T>(_ call: () async throws -> T) async throws -> T {
        if isBusy {
            await withCheckedContinuation { waiters.append($0) }    // the finishing request hands its turn over
        } else {
            isBusy = true
        }
        defer {
            if waiters.isEmpty { isBusy = false } else { waiters.removeFirst().resume() }
        }
        return try await call()
    }
}
