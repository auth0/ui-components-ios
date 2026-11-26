@testable import Auth0UniversalComponents
import Foundation

/// A clock a test moves by hand: `sleep` returns only when `advance` reaches it, and throws when its task is
/// cancelled, as `Task.sleep` does. No test of a toast waits for real time.
@MainActor
final class ManualToastClock: ToastSleeping {

    private final class Waiter: @unchecked Sendable {
        let wake: TimeInterval
        var continuation: CheckedContinuation<Void, Error>?
        var isCancelled = false

        init(wake: TimeInterval) { self.wake = wake }
    }

    private(set) var now: TimeInterval = 0
    /// Every duration a task asked to sleep for, in order: shows what the presenter decided.
    private(set) var requested: [TimeInterval] = []
    private var waiters: [Waiter] = []

    func sleep(seconds: TimeInterval) async throws {
        requested.append(seconds)
        let waiter = Waiter(wake: now + seconds)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if waiter.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    waiter.continuation = continuation
                    waiters.append(waiter)
                }
            }
        } onCancel: {
            Task { @MainActor in self.cancel(waiter) }
        }
    }

    private func cancel(_ waiter: Waiter) {
        waiter.isCancelled = true
        guard let continuation = waiter.continuation else { return }
        waiter.continuation = nil
        waiters.removeAll { $0 === waiter }
        continuation.resume(throwing: CancellationError())
    }

    /// Moves time forward, waking each sleeper when its time comes and letting what it does run before the next.
    func advance(by seconds: TimeInterval) async {
        // First let what the test just did take effect: a task it started registers its sleep, and one it cancelled
        // is woken with the cancellation, as `Task.sleep` does at once.
        await settle()
        let target = now + seconds
        while let next = waiters.filter({ $0.wake <= target }).min(by: { $0.wake < $1.wake }) {
            now = max(now, next.wake)
            waiters.removeAll { $0 === next }
            next.continuation?.resume()
            next.continuation = nil
            await settle()
        }
        now = target
        await settle()
    }

    /// Lets the tasks that are ready run.
    func settle() async {
        for _ in 0..<30 { await Task.yield() }
    }
}
