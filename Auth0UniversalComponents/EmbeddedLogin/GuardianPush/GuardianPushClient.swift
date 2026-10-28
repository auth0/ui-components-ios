import Foundation

/// A Guardian authenticator the user can approve the sign-in on.
public struct GuardianPushDevice: Identifiable, Hashable, Sendable {
    /// Selects this authenticator when sending the push. Pass it back unchanged; it isn't a position in a list.
    public let index: Int
    /// The enrollment name shown in Guardian (e.g. "iPhone").
    public let name: String

    public var id: Int { index }

    public init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

/// What the server said about a push that hasn't been approved yet.
public struct GuardianPushPending: Equatable, Sendable {
    /// Milliseconds to wait before the next check, when the server says.
    public var retryAfter: Int?
    /// The server still offers this push, so it can be sent again.
    public var canResend: Bool

    public init(retryAfter: Int? = nil, canResend: Bool = false) {
        self.retryAfter = retryAfter
        self.canResend = canResend
    }
}

/// The answer to one "has the user approved yet?" check.
public enum GuardianPushCheck<Approval> {
    case approved(Approval)
    /// Not approved yet.
    case pending(GuardianPushPending)
    /// Checking too often: wait longer before the next check.
    case slowDown(GuardianPushPending)
}

extension GuardianPushCheck: Equatable where Approval: Equatable {}

/// Why push approval ended without an approval.
public enum GuardianPushFailure: Error, Equatable, Sendable {
    /// No Guardian push authenticator is on offer for this sign-in.
    case unavailable
    /// The user denied the request in Guardian.
    case denied
    /// The request wasn't approved in time.
    case expired
    /// The sign-in session ended; a new sign-in is needed.
    case sessionEnded
    /// The request never reached the server. Retrying the same step is safe.
    case network
    /// Anything else. `message` is user-facing text, when there is some.
    case other(message: String?)

    /// Retrying the same step can still succeed. Otherwise the user must start a new sign-in.
    public var isRetryable: Bool { self == .network }
}

/// What the push component needs from the authorize loop: send the push, then check for approval.
///
/// `EmbeddedAuthGuardianPushClient` backs it with Auth0.swift's `EmbeddedAuth`. To use your own client,
/// conform to this protocol or wrap closures in `AnyGuardianPushClient`.
@MainActor
public protocol GuardianPushClient {
    /// The value an approval produces (e.g. `Credentials`).
    associatedtype Approval

    /// Sends the push to `device`. Throws `GuardianPushFailure` when it can't be sent.
    func sendPush(to device: GuardianPushDevice) async throws -> GuardianPushPending

    /// One approval check. Throws `GuardianPushFailure` for denial, expiry and other terminal outcomes.
    func checkApproval() async throws -> GuardianPushCheck<Approval>
}

/// A type-erased `GuardianPushClient`.
@MainActor
public struct AnyGuardianPushClient<Approval>: GuardianPushClient {
    private let send: (GuardianPushDevice) async throws -> GuardianPushPending
    private let check: () async throws -> GuardianPushCheck<Approval>

    /// Wraps closures, e.g. to back the component with your own API.
    public init(sendPush: @escaping (GuardianPushDevice) async throws -> GuardianPushPending,
                checkApproval: @escaping () async throws -> GuardianPushCheck<Approval>) {
        self.send = sendPush
        self.check = checkApproval
    }

    /// Wraps an existing client.
    public init<Client: GuardianPushClient>(_ client: Client) where Client.Approval == Approval {
        self.init(sendPush: { try await client.sendPush(to: $0) },
                  checkApproval: { try await client.checkApproval() })
    }

    public func sendPush(to device: GuardianPushDevice) async throws -> GuardianPushPending {
        try await send(device)
    }

    public func checkApproval() async throws -> GuardianPushCheck<Approval> {
        try await check()
    }

    /// Transforms an approval, e.g. storing the credentials before reporting success.
    /// An error thrown by `transform` ends the flow like any other failure.
    public func mapApproval<New>(_ transform: @escaping (Approval) throws -> New) -> AnyGuardianPushClient<New> {
        let check = self.check
        return AnyGuardianPushClient<New>(sendPush: send, checkApproval: {
            switch try await check() {
            case let .approved(approval): return .approved(try transform(approval))
            case let .pending(pending): return .pending(pending)
            case let .slowDown(pending): return .slowDown(pending)
            }
        })
    }
}
