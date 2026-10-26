@testable import Auth0UniversalComponents
import Foundation

/// In-memory `AuthInteracting` with scripted responses; records every call it receives.
/// An unscripted call throws `ScriptedAuthError.notScripted`. Calls in `held` suspend until `release(_:)`.
@MainActor
final class ScriptedAuthInteractor: AuthInteracting {

    enum Call: Hashable {
        case discover, startOTP, verifyOTP
    }

    enum Request: Equatable {
        case discover
        case startOTP(connection: String, email: String)
        case verifyOTP(code: String)
    }

    enum ScriptedAuthError: LocalizedError, Equatable {
        case notScripted(String)
        case scripted(message: String)

        var errorDescription: String? {
            switch self {
            case let .notScripted(call): return "\(call) was not scripted"
            case let .scripted(message): return message
            }
        }
    }

    private(set) var receivedRequests: [Request] = []

    var discoverResult: Result<[LoginOption], Error>?
    var startOTPResult: Result<Void, Error>?
    var verifyOTPResult: Result<AuthProgress, Error>?
    /// What `makeGuardianPushClient()` hands out.
    var pushClient = AnyGuardianPushClient<Void>(sendPush: { _ in GuardianPushPending(retryAfter: 1_000) },
                                                  checkApproval: { .approved(()) })

    var held: Set<Call> = []
    private var gates: [Call: CheckedContinuation<Void, Never>] = [:]

    init(
        discover: Result<[LoginOption], Error>? = nil,
        startOTP: Result<Void, Error>? = nil,
        verifyOTP: Result<AuthProgress, Error>? = nil
    ) {
        self.discoverResult = discover
        self.startOTPResult = startOTP
        self.verifyOTPResult = verifyOTP
    }

    func discover() async throws -> [LoginOption] {
        receivedRequests.append(.discover)
        await gate(.discover)
        return try resolve(discoverResult, call: "discover")
    }

    func startOTP(connection: String, email: String) async throws {
        receivedRequests.append(.startOTP(connection: connection, email: email))
        await gate(.startOTP)
        try resolve(startOTPResult, call: "startOTP")
    }

    func verifyOTP(code: String) async throws -> AuthProgress {
        receivedRequests.append(.verifyOTP(code: code))
        await gate(.verifyOTP)
        return try resolve(verifyOTPResult, call: "verifyOTP")
    }

    func makeGuardianPushClient() -> AnyGuardianPushClient<Void> { pushClient }

    /// Suspends until `call` is held at its gate.
    func waitUntilHeld(_ call: Call) async {
        while gates[call] == nil { await Task.yield() }
    }

    func release(_ call: Call) {
        held.remove(call)
        gates.removeValue(forKey: call)?.resume()
    }

    private func gate(_ call: Call) async {
        guard held.contains(call) else { return }
        await withCheckedContinuation { gates[call] = $0 }
    }

    @discardableResult
    private func resolve<T>(_ result: Result<T, Error>?, call: String) throws -> T {
        guard let result else { throw ScriptedAuthError.notScripted(call) }
        return try result.get()
    }
}
