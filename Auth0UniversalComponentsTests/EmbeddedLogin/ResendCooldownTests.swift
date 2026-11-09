@testable import Auth0UniversalComponents
import Foundation
import Testing

@Suite
struct ResendCooldownTests {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    @Test func countsDownFromTheStart_roundingUp() {
        let cooldown = ResendCooldown(seconds: 60, startedAt: start)
        #expect(cooldown.remaining(at: start) == 60)
        #expect(cooldown.remaining(at: start.addingTimeInterval(0.4)) == 60)
        #expect(cooldown.remaining(at: start.addingTimeInterval(59.1)) == 1)
        #expect(cooldown.remaining(at: start.addingTimeInterval(60)) == 0)
        #expect(cooldown.remaining(at: start.addingTimeInterval(500)) == 0)
    }

    /// Measured from the start, so however often the view redraws, the remaining time is the same.
    @Test func dependsOnlyOnTheTime_notOnHowOftenItIsRead() {
        let cooldown = ResendCooldown(seconds: 60, startedAt: start)
        for _ in 0..<1_000 { _ = cooldown.remaining(at: start.addingTimeInterval(10)) }
        #expect(cooldown.remaining(at: start.addingTimeInterval(30)) == 30)
    }

    @Test func restart_startsAFullCooldown() {
        var cooldown = ResendCooldown(seconds: 60, startedAt: start)
        let later = start.addingTimeInterval(90)
        #expect(cooldown.remaining(at: later) == 0)
        cooldown.restart(at: later)
        #expect(cooldown.remaining(at: later) == 60)
    }
}
