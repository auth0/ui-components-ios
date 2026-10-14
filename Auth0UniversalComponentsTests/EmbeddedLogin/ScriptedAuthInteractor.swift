@testable import Auth0UniversalComponents
import Foundation

/// In-memory `AuthInteracting` with scripted responses; records every call it receives.
/// An unscripted call throws `ScriptedAuthError.notScripted`. Calls in `held` suspend until `release(_:)`.
@MainActor
final class ScriptedAuthInteractor: AuthInteracting {

    enum Call: Hashable {
        case discover, startOTP, verifyOTP, verifyMFA
    }

    enum Request: Equatable {
        case discover
        case startOTP(connection: String, email: String)
        case verifyOTP(code: String)
        case verifyMFA(code: String, factor: MFAFactor)
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
    var verifyOTPResult: Result<AuthOutcome, Error>?
    var verifyMFAResult: Result<AuthOutcome, Error>?

    var held: Set<Call> = []
    private var gates: [Call: CheckedContinuation<Void, Never>] = [:]

    init(
        discover: Result<[LoginOption], Error>? = nil,
        startOTP: Result<Void, Error>? = nil,
        verifyOTP: Result<AuthOutcome, Error>? = nil,
        verifyMFA: Result<AuthOutcome, Error>? = nil
    ) {
        self.discoverResult = discover
        self.startOTPResult = startOTP
        self.verifyOTPResult = verifyOTP
        self.verifyMFAResult = verifyMFA
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

    func verifyOTP(code: String) async throws -> AuthOutcome {
        receivedRequests.append(.verifyOTP(code: code))
        await gate(.verifyOTP)
        return try resolve(verifyOTPResult, call: "verifyOTP")
    }

    func verifyMFA(code: String, factor: MFAFactor) async throws -> AuthOutcome {
        receivedRequests.append(.verifyMFA(code: code, factor: factor))
        await gate(.verifyMFA)
        return try resolve(verifyMFAResult, call: "verifyMFA")
    }

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
