import Auth0
import Foundation

/// `GuardianPushClient` backed by Auth0.swift's Embedded Authorization client. Approval yields `Credentials`.
///
/// Use the same `EmbeddedAuth` instance that ran the first factor, so the push continues that sign-in:
///
/// ```swift
/// let devices = EmbeddedAuthGuardianPushClient.devices(in: nextActions)
/// let controller = GuardianPushApprovalController(client: EmbeddedAuthGuardianPushClient(auth: auth),
///                                                 devices: devices) { credentials in /* store them */ }
/// ```
public struct EmbeddedAuthGuardianPushClient: GuardianPushClient {
    public typealias Approval = Credentials

    private let client: EmbeddedAuthClient

    public init(auth: EmbeddedAuth) {
        self.client = LiveEmbeddedAuthClient(auth: auth)
    }

    init(client: EmbeddedAuthClient) {
        self.client = client
    }

    /// The Guardian devices in an `insufficient_authorization` menu, in server order.
    public static func devices(in nextActions: [NextAction]) -> [GuardianPushDevice] {
        nextActions.compactMap { action in
            guard case let .challengePush(index, name) = action else { return nil }
            return GuardianPushDevice(index: index, name: name)
        }
    }

    public func sendPush(to device: GuardianPushDevice) async throws -> GuardianPushPending {
        do {
            try await client.challengePush(index: device.index)
        } catch let error as EmbeddedAuthError {
            guard case let .insufficientAuthorization(_, nextActions) = error.reason else {
                throw Self.failure(for: error)
            }
            // The push went out when the server asks to check for approval next.
            guard let pending = Self.pending(in: nextActions) else {
                throw GuardianPushFailure.other(message: nil)
            }
            return pending
        }
        // Success here means the loop closed without an approval step; treat it as an error.
        throw GuardianPushFailure.other(message: nil)
    }

    public func checkApproval() async throws -> GuardianPushCheck<Credentials> {
        do {
            return .approved(try await client.verifyOob())
        } catch let error as EmbeddedAuthError {
            switch error.reason {
            case let .insufficientAuthorization(.authorizationPending, nextActions):
                return .pending(GuardianPushPending(retryAfter: Self.pollInterval(in: nextActions),
                                                    canResend: Self.offersPush(in: nextActions)))
            case let .insufficientAuthorization(.slowDown, nextActions):
                return .slowDown(GuardianPushPending(retryAfter: Self.pollInterval(in: nextActions),
                                                     canResend: Self.offersPush(in: nextActions)))
            default:
                throw Self.failure(for: error)
            }
        }
    }

    // MARK: Mapping

    static func failure(for error: EmbeddedAuthError) -> GuardianPushFailure {
        switch error.reason {
        case .network: return .network
        case .authorizationRejected: return .denied
        case .challengeExpired: return .expired
        case .noActiveSession, .sessionExpired: return .sessionEnded
        case .noEligibleFactors: return .unavailable
        case .insufficientAuthorization, .tooManyWrongOtpAttempts, .accessDenied, .consentRequired, .invalidRequest,
             .tooManyAttempts, .tooManyLogins, .ipBlocked, .unknown:
            return .other(message: error.displayMessage)
        @unknown default:
            return .other(message: error.displayMessage)
        }
    }

    private static func pending(in nextActions: [NextAction]) -> GuardianPushPending? {
        guard let interval = pollInterval(in: nextActions) else { return nil }
        return GuardianPushPending(retryAfter: interval, canResend: offersPush(in: nextActions))
    }

    private static func pollInterval(in nextActions: [NextAction]) -> Int? {
        for case let .verifyOob(pollInMs) in nextActions { return pollInMs }
        return nil
    }

    private static func offersPush(in nextActions: [NextAction]) -> Bool {
        !devices(in: nextActions).isEmpty
    }
}
