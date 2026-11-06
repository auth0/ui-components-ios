@testable import Auth0UniversalComponents
import Foundation
import Testing

@MainActor
final class ScriptedPhoneCodeTransport: PhoneCodeTransport {
    var sends: [Result<PhoneCodeSent, MfaError>]
    var verifies: [Result<PhoneCodeVerification, MfaError>]
    private(set) var log: [String] = []

    init(send: [Result<PhoneCodeSent, MfaError>] = [], verify: [Result<PhoneCodeVerification, MfaError>] = []) {
        sends = send
        verifies = verify
    }

    func sendCode(to offer: MfaFactorOffer) async throws -> PhoneCodeSent {
        log.append("send \(offer.id)")
        return try (sends.isEmpty ? .success(PhoneCodeSent(canResend: true)) : sends.removeFirst()).get()
    }

    func verify(code: String) async throws -> PhoneCodeVerification {
        log.append("verify \(code)")
        return try (verifies.isEmpty ? .success(.verified) : verifies.removeFirst()).get()
    }
}

/// The SMS session on its own, with a fake Core around it.
@Suite
@MainActor
struct PhoneCodeSessionTests {

    private let offer = scriptedOffer("sms:0", factor: .sms, label: "(4**)***-*900")
    private let clock = ManualMfaClock()
    private let host = FakeHost()

    /// `cooldown` is the resend wait in seconds; the tests that are not about it use none.
    private func session(_ transport: ScriptedPhoneCodeTransport, cooldown: Int = 0,
                         ledger: PhoneCodeSendLedger? = nil) -> PhoneCodeSession {
        PhoneCodeSession(offer: offer, delivery: .text, transport: transport,
                         policy: PhoneCodePolicy(resendCooldownSeconds: cooldown), clock: clock, host: host,
                         ledger: ledger)
    }

    private func model(_ session: PhoneCodeSession) -> PhoneCodeChallengeModel? {
        session.model as? PhoneCodeChallengeModel
    }

    @Test func sendingShowsNothing_thenTheCodeScreen() async {
        let transport = ScriptedPhoneCodeTransport()
        let sut = session(transport)
        sut.start()
        #expect(sut.model == nil, "the code is still being sent")
        await eventually { model(sut) != nil }
        #expect(model(sut)?.destination == "(4**)***-*900")
        #expect(model(sut)?.codeLength == 6)
        #expect(model(sut)?.canResend == true)
        #expect(transport.log == ["send sms:0"])
    }

    @Test func theRightCode_reportsCompletedOnce() async {
        let transport = ScriptedPhoneCodeTransport()
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.submit("123456")
        #expect(model(sut)?.isVerifying == true)
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["send sms:0", "verify 123456"])
        #expect(host.events == ["completed"])
    }

    @Test func aWrongCode_staysOnTheScreen_thenTheRightOneSignsIn() async {
        let transport = ScriptedPhoneCodeTransport(verify: [.success(.rejected(canResend: true)), .success(.verified)])
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.submit("000000")
        await eventually { model(sut)?.isCodeRejected == true }
        #expect(model(sut)?.isVerifying == false)
        #expect(host.events.isEmpty)

        model(sut)?.submit("123456")
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["send sms:0", "verify 000000", "verify 123456"])
    }

    @Test func resend_sendsAgain_andKeepsTheScreenUp() async {
        let transport = ScriptedPhoneCodeTransport()
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.resend()
        #expect(model(sut) != nil, "the code screen stays while the new code is sent")
        await eventually { transport.log.count == 2 }
        #expect(transport.log == ["send sms:0", "send sms:0"])
    }

    @Test func theResendWait_countsDownOnTheClock() async {
        let sut = session(ScriptedPhoneCodeTransport(), cooldown: 2)
        sut.start()
        await eventually { model(sut) != nil }
        #expect(model(sut)?.resendAvailableIn == 2)

        model(sut)?.resend()
        await settle()
        #expect(model(sut)?.resendAvailableIn == 2, "resend does nothing while it counts down")

        await clock.advance()
        await eventually { model(sut)?.resendAvailableIn == 1 }
        await clock.advance()
        await eventually { model(sut)?.resendAvailableIn == 0 }
    }

    @Test func anotherFactor_isPassedOn() async {
        let next = [scriptedOffer("push:0", factor: .push, label: "iPhone")]
        let sut = session(ScriptedPhoneCodeTransport(verify: [.success(.anotherFactor(next))]))
        sut.start()
        await eventually { model(sut) != nil }
        model(sut)?.submit("123456")
        await eventually { host.events == ["menu"] }
        #expect(host.offers == [next])
    }

    @Test func aFailedSend_isReported() async {
        let sut = session(ScriptedPhoneCodeTransport(send: [.failure(.tooManyAttempts)]))
        sut.start()
        await eventually { host.events == ["failed"] }
        #expect(host.errors == [.tooManyAttempts])
        #expect(sut.model == nil)
    }

    @Test func switchAndCancel_goToTheCore() async {
        host.canSwitch = true
        let sut = session(ScriptedPhoneCodeTransport())
        sut.start()
        await eventually { model(sut) != nil }
        #expect(model(sut)?.canSwitch == true)
        model(sut)?.switchFactor()
        model(sut)?.cancel()
        #expect(host.events == ["switch", "cancel"])
    }

    @Test func afterTheFlowEnds_nothingMoreIsSent() async {
        let transport = ScriptedPhoneCodeTransport()
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }
        let stale = model(sut)

        await sut.cancelAndWait()
        stale?.submit("123456")
        stale?.resend()
        await settle()
        #expect(transport.log == ["send sms:0"])
        #expect(host.events.isEmpty)
    }

    // MARK: Failures that leave the code usable

    @Test func aDroppedConnectionWhileChecking_staysOnTheScreen_andTheSameCodeCanBeSentAgain() async {
        let transport = ScriptedPhoneCodeTransport(verify: [.failure(.network), .success(.verified)])
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.submit("123456")
        await eventually { model(sut)?.requestError == .network }
        #expect(model(sut)?.isVerifying == false)
        #expect(host.events.isEmpty, "the flow goes on")

        model(sut)?.submit("123456")
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["send sms:0", "verify 123456", "verify 123456"])
    }

    @Test func aResendThatFails_staysOnTheScreen_andTheCodeOnThePhoneStillWorks() async {
        let transport = ScriptedPhoneCodeTransport(send: [.success(PhoneCodeSent(canResend: true)), .failure(.network)])
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.resend()
        await eventually { model(sut)?.requestError == .network }
        #expect(host.events.isEmpty, "the flow goes on")
        #expect(model(sut)?.canResend == true, "and the user can try again")

        model(sut)?.submit("123456")
        await eventually { host.events == ["completed"] }
    }

    @Test func aResendTheServerRefuses_staysOnTheScreen() async {
        let transport = ScriptedPhoneCodeTransport(
            send: [.success(PhoneCodeSent(canResend: true)), .failure(.tooManyAttempts)])
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.resend()
        await eventually { model(sut)?.requestError == .tooManyAttempts }
        #expect(host.events.isEmpty)
    }

    @Test func anExpiredCode_staysOnTheScreen_untilANewOneIsSent() async {
        let transport = ScriptedPhoneCodeTransport(verify: [.failure(.tokenExpired)])
        let sut = session(transport, cooldown: 60)
        sut.start()
        await eventually { model(sut) != nil }
        #expect(model(sut)?.resendAvailableIn == 60)

        model(sut)?.submit("123456")
        await eventually { model(sut)?.isCodeExpired == true }
        #expect(host.events.isEmpty, "the flow goes on")
        #expect(model(sut)?.resendAvailableIn == 0, "only a new code helps, so resend is open at once")

        model(sut)?.submit("123456")
        await settle()
        #expect(transport.log == ["send sms:0", "verify 123456"], "an expired code isn't checked again")

        model(sut)?.resend()
        await eventually { transport.log.count == 3 }
        await eventually { model(sut)?.isCodeExpired == false }
        #expect(transport.log.last == "send sms:0")
    }

    @Test func tooManyWrongCodes_endTheFactor() async {
        let sut = session(ScriptedPhoneCodeTransport(verify: [.failure(.tooManyAttempts)]))
        sut.start()
        await eventually { model(sut) != nil }
        model(sut)?.submit("000000")
        await eventually { host.events == ["failed"] }
        #expect(host.errors == [.tooManyAttempts])
    }

    // MARK: Coming back to a phone that was just sent a code

    /// A wall clock the tests move by hand.
    @MainActor
    private final class Wall {
        var now = Date(timeIntervalSince1970: 1_000_000)
    }

    private func leaveAndCome(back transport: ScriptedPhoneCodeTransport, after seconds: TimeInterval,
                              ledger: PhoneCodeSendLedger, wall: Wall) -> PhoneCodeSession {
        wall.now.addTimeInterval(seconds)
        let again = session(transport, cooldown: 60, ledger: ledger)
        again.start()
        return again
    }

    @Test func comingBackToAPhoneJustSent_showsThatCodeAgain_andSendsNothing() async {
        let wall = Wall()
        let ledger = PhoneCodeSendLedger(now: { wall.now })
        let transport = ScriptedPhoneCodeTransport()
        let first = session(transport, cooldown: 60, ledger: ledger)
        first.start()
        await eventually { model(first) != nil }
        first.deactivate()                                                  // "Verify another way"

        let again = leaveAndCome(back: transport, after: 10, ledger: ledger, wall: wall)
        #expect(model(again) != nil, "the code screen is back at once")
        #expect(model(again)?.canResend == true)
        #expect(model(again)?.resendAvailableIn == 50, "the wait carries over")
        await settle()
        #expect(transport.log == ["send sms:0"], "no second code")
    }

    @Test func comingBackAfterTheWait_sendsANewCode() async {
        let wall = Wall()
        let ledger = PhoneCodeSendLedger(now: { wall.now })
        let transport = ScriptedPhoneCodeTransport()
        let first = session(transport, cooldown: 60, ledger: ledger)
        first.start()
        await eventually { model(first) != nil }
        first.deactivate()

        let again = leaveAndCome(back: transport, after: 60, ledger: ledger, wall: wall)
        await eventually { model(again) != nil }
        #expect(transport.log == ["send sms:0", "send sms:0"])
    }

    @Test func comingBackToACodeThatWasUsed_sendsANewOne() async {
        let wall = Wall()
        let ledger = PhoneCodeSendLedger(now: { wall.now })
        let next = [scriptedOffer("push:0", factor: .push, label: "iPhone")]
        let transport = ScriptedPhoneCodeTransport(verify: [.success(.anotherFactor(next))])
        let first = session(transport, cooldown: 60, ledger: ledger)
        first.start()
        await eventually { model(first) != nil }
        model(first)?.submit("123456")
        await eventually { host.events == ["menu"] }

        let again = leaveAndCome(back: transport, after: 5, ledger: ledger, wall: wall)
        await eventually { model(again) != nil }
        #expect(transport.log == ["send sms:0", "verify 123456", "send sms:0"],
                "the used code is no use, so a new one went out")
    }

    @Test func comingBackAfterAWrongCode_stillHoldsTheWait() async {
        let wall = Wall()
        let ledger = PhoneCodeSendLedger(now: { wall.now })
        let transport = ScriptedPhoneCodeTransport(verify: [.success(.rejected(canResend: true))])
        let first = session(transport, cooldown: 60, ledger: ledger)
        first.start()
        await eventually { model(first) != nil }
        model(first)?.submit("000000")
        await eventually { model(first)?.isCodeRejected == true }
        first.deactivate()

        let again = leaveAndCome(back: transport, after: 5, ledger: ledger, wall: wall)
        #expect(model(again)?.resendAvailableIn == 55)
        await settle()
        #expect(transport.log.filter { $0.hasPrefix("send") }.count == 1, "the code on the phone is still good")
    }
}
