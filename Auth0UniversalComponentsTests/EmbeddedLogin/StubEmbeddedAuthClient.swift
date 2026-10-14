@testable import Auth0UniversalComponents
import Auth0
import Foundation

/// Scripted `EmbeddedAuthClient`: each call pops the next result queued for it and records itself.
/// An unscripted call succeeds (`verifyOtp` returns empty credentials).
@MainActor
final class StubEmbeddedAuthClient: EmbeddedAuthClient {

    enum Call: Equatable {
        case authorize(connection: String)
        case identify(email: String)
        case challengeEmail(index: Int)
        case verifyOtp(code: String, type: OtpType)
    }

    private(set) var calls: [Call] = []

    var authorizeResults: [Error?] = []
    var identifyResults: [Error?] = []
    var challengeEmailResults: [Error?] = []
    var verifyOtpResults: [Result<Credentials, Error>] = []

    func authorize(connection: String) async throws {
        calls.append(.authorize(connection: connection))
        if let error = authorizeResults.popFirst() ?? nil { throw error }
    }

    func identify(email: String) async throws {
        calls.append(.identify(email: email))
        if let error = identifyResults.popFirst() ?? nil { throw error }
    }

    func challengeEmail(index: Int) async throws {
        calls.append(.challengeEmail(index: index))
        if let error = challengeEmailResults.popFirst() ?? nil { throw error }
    }

    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials {
        calls.append(.verifyOtp(code: code, type: type))
        return try (verifyOtpResults.popFirst() ?? .success(Credentials())).get()
    }
}

final class StubCredentialsStore: CredentialsStoring {
    var error: Error?
    private(set) var stored: [Credentials] = []

    func store(credentials: Credentials) throws {
        if let error { throw error }
        stored.append(credentials)
    }
}

// MARK: - Server responses, in the SDK's wire format

enum EmbeddedAuthFixtures {
    static let identifyEmail: [String: Any] = ["action": "action:identify:email:v1"]
    static let challengeEmail: [String: Any] = ["action": "action:challenge:email:v1", "index": 1,
                                                "identifier": "s***@atko.email"]
    static let verifyEmail: [String: Any] = ["action": "action:verify:otp:v1", "channel": "email"]
    static let verifyTOTP: [String: Any] = ["action": "action:verify:otp:v1", "channel": "totp"]
    static let verifySMS: [String: Any] = ["action": "action:verify:otp:v1", "channel": "sms",
                                           "identifier": "+1***99"]

    /// `insufficient_authorization` advertising `next`, optionally with a sub-reason.
    static func needs(_ next: [[String: Any]], subReason: String? = nil) -> EmbeddedAuthError {
        var info: [String: Any] = ["error": "insufficient_authorization", "next": next]
        if let subReason { info["error_description"] = subReason }
        return EmbeddedAuthError(info: info, statusCode: 403)
    }

    static func terminal(_ code: String, description: String, statusCode: Int = 403) -> EmbeddedAuthError {
        EmbeddedAuthError(info: ["error": code, "error_description": description], statusCode: statusCode)
    }
}

private extension Array {
    mutating func popFirst() -> Element? { isEmpty ? nil : removeFirst() }
}
