@testable import Auth0UniversalComponents
import Foundation
import Testing

/// What is left of the wait after a code was sent to a phone, as sessions come and go.
@Suite
@MainActor
struct PhoneCodeSendLedgerTests {

    private final class Wall {
        var now = Date(timeIntervalSince1970: 1_000_000)
    }

    private let wall = Wall()
    private func ledger() -> PhoneCodeSendLedger { PhoneCodeSendLedger(now: { [wall] in wall.now }) }

    @Test func aPhoneNothingWasSentTo_hasNoWait() {
        #expect(ledger().earlier("sms:0", cooldownSeconds: 60) == nil)
    }

    @Test func afterASend_theRestOfTheWaitIsLeft_withWhatTheServerOffered() {
        let sut = ledger()
        sut.sent("sms:0", canResend: false)
        wall.now.addTimeInterval(10)
        #expect(sut.earlier("sms:0", cooldownSeconds: 60) == .init(resendAvailableIn: 50, canResend: false))
    }

    @Test func whenTheWaitIsOver_nothingIsLeft() {
        let sut = ledger()
        sut.sent("sms:0", canResend: true)
        wall.now.addTimeInterval(60)
        #expect(sut.earlier("sms:0", cooldownSeconds: 60) == nil)
        wall.now.addTimeInterval(600)
        #expect(sut.earlier("sms:0", cooldownSeconds: 60) == nil)
    }

    @Test func aPartOfASecond_countsAsAWholeOne() {
        let sut = ledger()
        sut.sent("sms:0", canResend: true)
        wall.now.addTimeInterval(59.5)
        #expect(sut.earlier("sms:0", cooldownSeconds: 60)?.resendAvailableIn == 1)
    }

    @Test func aClockSetBack_isNeverALongerWaitThanTheWait() {
        let sut = ledger()
        sut.sent("sms:0", canResend: true)
        wall.now.addTimeInterval(-3_600)
        #expect(sut.earlier("sms:0", cooldownSeconds: 60)?.resendAvailableIn == 60)
    }

    @Test func noWaitConfigured_meansNoWait() {
        let sut = ledger()
        sut.sent("sms:0", canResend: true)
        #expect(sut.earlier("sms:0", cooldownSeconds: 0) == nil)
    }

    @Test func aSendOnItsWay_alreadyHoldsTheWait_andIsGivenTheBenefitOfTheDoubt() {
        let sut = ledger()
        sut.sending("sms:0")
        wall.now.addTimeInterval(20)
        #expect(sut.earlier("sms:0", cooldownSeconds: 60) == .init(resendAvailableIn: 40, canResend: true))
    }

    @Test func theAnswer_startsTheWaitAgain() {
        let sut = ledger()
        sut.sending("sms:0")
        wall.now.addTimeInterval(5)
        sut.sent("sms:0", canResend: false)
        #expect(sut.earlier("sms:0", cooldownSeconds: 60) == .init(resendAvailableIn: 60, canResend: false))
    }

    @Test func aUsedCode_isForgotten() {
        let sut = ledger()
        sut.sent("sms:0", canResend: true)
        sut.forget("sms:0")
        #expect(sut.earlier("sms:0", cooldownSeconds: 60) == nil)
    }

    @Test func eachPhoneHasItsOwnWait() {
        let sut = ledger()
        sut.sent("sms:0", canResend: true)
        #expect(sut.earlier("sms:1", cooldownSeconds: 60) == nil)
        #expect(sut.earlier("voice:0", cooldownSeconds: 60) == nil)
    }
}
