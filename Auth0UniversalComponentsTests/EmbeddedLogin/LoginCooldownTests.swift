@testable import Auth0UniversalComponents
import Foundation
import Testing

/// The wait before a code can be asked for again, and how the code button words it.
@Suite
struct LoginCooldownTests {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func theSecondsLeft_roundUp_andStopAtZero() {
        let end = start.addingTimeInterval(60)
        #expect(ResendCooldown.remaining(until: end, at: start) == 60)
        #expect(ResendCooldown.remaining(until: end, at: start.addingTimeInterval(0.2)) == 60)
        #expect(ResendCooldown.remaining(until: end, at: start.addingTimeInterval(59.5)) == 1)
        #expect(ResendCooldown.remaining(until: end, at: end) == 0)
        #expect(ResendCooldown.remaining(until: end, at: end.addingTimeInterval(30)) == 0)
    }

    @Test func aCooldownMeasuredFromItsStart_agreesWithOneMeasuredToItsEnd() {
        let cooldown = ResendCooldown(seconds: 60, startedAt: start)
        let later = start.addingTimeInterval(17)
        let end = start.addingTimeInterval(60)
        #expect(cooldown.remaining(at: later) == ResendCooldown.remaining(until: end, at: later))
    }

    @Test func theCodeButton_countsDownInItsTitle() {
        #expect(LoginCodeAlternativeButton.title("Email me a code", remaining: 0) == "Email me a code")
        #expect(LoginCodeAlternativeButton.title("Email me a code", remaining: 42) == "Email me a code in 42s")
    }

    @Test func theCoordinatorsWait_isTheResendWait() {
        #expect(ResendCooldown.defaultSeconds == 60)
    }
}
