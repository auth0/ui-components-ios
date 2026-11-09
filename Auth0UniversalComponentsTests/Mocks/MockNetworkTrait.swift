import Testing

/// `MockURLProtocol.requestHandler` is one global, so two suites that set it can't run at the same time. `.serialized`
/// only orders the tests inside a suite; this lets one such suite run at a time.
struct MockNetworkTrait: SuiteTrait, TestScoping {
    func provideScope(for test: Test, testCase: Test.Case?,
                      performing function: @concurrent @Sendable () async throws -> Void) async throws {
        await MockNetworkLock.shared.acquire()
        do {
            try await function()
        } catch {
            await MockNetworkLock.shared.release()
            throw error
        }
        await MockNetworkLock.shared.release()
    }
}

extension Trait where Self == MockNetworkTrait {
    static var mockNetwork: Self { Self() }
}

private actor MockNetworkLock {
    static let shared = MockNetworkLock()
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if isBusy {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            isBusy = true
        }
    }

    func release() {
        if waiters.isEmpty { isBusy = false } else { waiters.removeFirst().resume() }
    }
}
