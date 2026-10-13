@testable import Auth0UniversalComponents
import Foundation

/// In-memory `AuthInteracting` with scripted responses; records every call it receives.
/// An unscripted call throws `ScriptedAuthError.notScripted`.
final class ScriptedAuthInteractor: AuthInteracting {

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
        return try resolve(discoverResult, call: "discover")
    }

    func startOTP(connection: String, email: String) async throws {
        receivedRequests.append(.startOTP(connection: connection, email: email))
        try resolve(startOTPResult, call: "startOTP")
    }

    func verifyOTP(code: String) async throws -> AuthOutcome {
        receivedRequests.append(.verifyOTP(code: code))
        return try resolve(verifyOTPResult, call: "verifyOTP")
    }

    func verifyMFA(code: String, factor: MFAFactor) async throws -> AuthOutcome {
        receivedRequests.append(.verifyMFA(code: code, factor: factor))
        return try resolve(verifyMFAResult, call: "verifyMFA")
    }

    @discardableResult
    private func resolve<T>(_ result: Result<T, Error>?, call: String) throws -> T {
        guard let result else { throw ScriptedAuthError.notScripted(call) }
        return try result.get()
    }
}
