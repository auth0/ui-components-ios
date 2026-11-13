@testable import Auth0UniversalComponents
import Foundation

extension LoginFlowCoordinator {
    /// Whether the password screen on display offers a code instead.
    var canSendCode: Bool {
        if case let .collectPassword(_, canSendCode) = step { return canSendCode }
        return false
    }

    /// Whether the code screen on display offers a password instead.
    var canUsePassword: Bool {
        if case let .collectOTPCode(_, _, canUsePassword) = step { return canUsePassword }
        return false
    }
}

extension LoginFlowCoordinator {
    /// The step without the alternative it offers, to say which screen is on display; the offers are checked on their
    /// own through `canSendCode` and `canUsePassword`.
    var screen: LoginStep {
        switch step {
        case let .collectPassword(identifier, _): return .collectPassword(identifier: identifier)
        case let .collectOTPCode(identifier, sentTo, _): return .collectOTPCode(identifier: identifier, sentTo: sentTo)
        default: return step
        }
    }
}

/// A clock a test moves by hand.
@MainActor
final class TestClock {
    private(set) var now = Date(timeIntervalSinceReferenceDate: 1_000)

    func advance(by seconds: TimeInterval) { now.addTimeInterval(seconds) }

    /// Past the wait before a code can be asked for again.
    func waitOutTheCodeCooldown() { advance(by: TimeInterval(ResendCooldown.defaultSeconds)) }
}
