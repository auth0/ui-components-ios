@testable import Auth0UniversalComponents
import Auth0
import Foundation

/// Scripted `EmbeddedAuthClient`: each call pops the next result queued for it and records itself.
/// An unscripted call succeeds (`verifyOtp` returns empty credentials).
@MainActor
final class StubEmbeddedAuthClient: EmbeddedAuthClient {

    enum Call: Equatable {
        case authorize(connection: String)
        case identify(_ identifier: String, type: IdentifierType)
        case challengeEmail(index: Int)
        case challengePhone(index: Int, deliveryMethod: PhoneDeliveryMethod)
        case verifyOtp(code: String, type: OtpType)
        case challengePush(index: Int)
        case verifyOob
        case verifyRecoveryCode(code: String)
        case confirmRecoveryCode
    }

    private(set) var calls: [Call] = []

    var authorizeResults: [Error?] = []
    var identifyResults: [Error?] = []
    var challengeEmailResults: [Error?] = []
    var challengePhoneResults: [Error?] = []
    var verifyOtpResults: [Result<Credentials, Error>] = []
    var challengePushResults: [Error?] = []
    var verifyOobResults: [Result<Credentials, Error>] = []
    var verifyRecoveryCodeResults: [Error?] = []
    var confirmRecoveryCodeResults: [Result<Credentials, Error>] = []

    func authorize(connection: String) async throws {
        calls.append(.authorize(connection: connection))
        if let error = authorizeResults.popFirst() ?? nil { throw error }
    }

    func identify(_ identifier: String, type: IdentifierType) async throws {
        calls.append(.identify(identifier, type: type))
        if let error = identifyResults.popFirst() ?? nil { throw error }
    }

    func challengeEmail(index: Int) async throws {
        calls.append(.challengeEmail(index: index))
        if let error = challengeEmailResults.popFirst() ?? nil { throw error }
    }

    func challengePhone(index: Int, deliveryMethod: PhoneDeliveryMethod) async throws {
        calls.append(.challengePhone(index: index, deliveryMethod: deliveryMethod))
        if let error = challengePhoneResults.popFirst() ?? nil { throw error }
    }

    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials {
        calls.append(.verifyOtp(code: code, type: type))
        return try (verifyOtpResults.popFirst() ?? .success(Credentials())).get()
    }

    func challengePush(index: Int) async throws {
        calls.append(.challengePush(index: index))
        if let error = challengePushResults.popFirst() ?? nil { throw error }
    }

    func verifyOob() async throws -> Credentials {
        calls.append(.verifyOob)
        return try (verifyOobResults.popFirst() ?? .success(Credentials())).get()
    }

    func verifyRecoveryCode(_ code: String) async throws {
        calls.append(.verifyRecoveryCode(code: code))
        if let error = verifyRecoveryCodeResults.popFirst() ?? nil { throw error }
    }

    func confirmRecoveryCode() async throws -> Credentials {
        calls.append(.confirmRecoveryCode)
        return try (confirmRecoveryCodeResults.popFirst() ?? .success(Credentials())).get()
    }
}

final class StubCredentialsDelivery: CredentialsDelivering {
    var error: Error?
    private(set) var delivered: [Credentials] = []

    func deliver(credentials: Credentials) throws {
        if let error { throw error }
        delivered.append(credentials)
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
    static let verifyVoice: [String: Any] = ["action": "action:verify:otp:v1", "channel": "voice",
                                             "identifier": "+1***99"]
    static let challengePush: [String: Any] = ["action": "action:challenge:push:v1", "index": 0,
                                               "name": "Sudhanshu's iPhone"]
    static let identifyPhone: [String: Any] = ["action": "action:identify:phone:v1"]
    static let verifyRecoveryCode: [String: Any] = ["action": "action:verify:recovery-code:v1"]
    static func confirmRecoveryCode(newCode: String = "N47HCYSDHRKWWSLJONYEQ7LXLV5XEMC5") -> [String: Any] {
        ["action": "action:confirm:recovery-code:v1", "new_code": newCode]
    }

    static func challengePhone(index: Int = 0, masked: String = "(4**)***-*900",
                               methods: [String] = ["text", "voice"]) -> [String: Any] {
        ["action": "action:challenge:phone:v1", "index": index, "identifier": masked, "delivery_methods": methods]
    }

    static func verifyOob(pollInMs: Int = 2_000) -> [String: Any] {
        ["action": "action:verify:oob:v1", "poll_in_ms": pollInMs]
    }

    /// `insufficient_authorization` advertising `next`, optionally with a sub-reason.
    static func needs(_ next: [[String: Any]], subReason: String? = nil) -> EmbeddedAuthError {
        var info: [String: Any] = ["error": "insufficient_authorization", "next": next]
        if let subReason { info["error_description"] = subReason }
        return EmbeddedAuthError(info: info, statusCode: 403)
    }

    static func terminal(_ code: String, description: String, statusCode: Int = 403) -> EmbeddedAuthError {
        EmbeddedAuthError(info: ["error": code, "error_description": description], statusCode: statusCode)
    }

    /// The request never reached the server.
    static var network: EmbeddedAuthError {
        EmbeddedAuthError(info: ["cause": URLError(.notConnectedToInternet)], statusCode: 0)
    }

    /// The SDK's local guard when no flow is active.
    static var noActiveSession: EmbeddedAuthError {
        EmbeddedAuthError(info: ["error": "no_active_session"], statusCode: 0)
    }
}

private extension Array {
    mutating func popFirst() -> Element? { isEmpty ? nil : removeFirst() }
}
