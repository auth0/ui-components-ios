@testable import Auth0UniversalComponents
import SwiftUI
import Testing

/// The email code session on its own, with a fake Core around it. The engine under it has its own suites
/// (`PhoneCodeMachineTests`, `PhoneCodeSessionTests`); these check what the email factor adds: the address in the
/// model, the actions passed through, and one wait for all of the factor's sessions.
@Suite
@MainActor
struct EmailCodeSessionTests {

    private let offer = scriptedOffer("email:2", factor: .email, label: "s***@atko.email")
    private let clock = ManualMfaClock()
    private let host = FakeHost()

    private func session(_ transport: ScriptedPhoneCodeTransport, offer: MfaFactorOffer? = nil) -> EmailCodeSession {
        EmailCodeSession(offer: offer ?? self.offer, transport: transport,
                         policy: EmailCodePolicy(resendCooldownSeconds: 0), clock: clock, host: host)
    }

    private func model(_ session: EmailCodeSession) -> EmailCodeChallengeModel? {
        session.model as? EmailCodeChallengeModel
    }

    @Test func sendingShowsNothing_thenTheCodeScreen_namingTheAddress() async {
        let transport = ScriptedPhoneCodeTransport()
        let sut = session(transport)
        sut.start()
        #expect(sut.model == nil, "the code is still being sent")
        await eventually { model(sut) != nil }
        #expect(model(sut)?.address == "s***@atko.email")
        #expect(model(sut)?.codeLength == 6)
        #expect(model(sut)?.canResend == true)
        #expect(transport.log == ["send email:2"])
    }

    @Test func anOfferWithoutAnAddress_givesAnEmptyAddress() async {
        let sut = session(ScriptedPhoneCodeTransport(), offer: scriptedOffer("email:0", factor: .email))
        sut.start()
        await eventually { model(sut) != nil }
        #expect(model(sut)?.address == "")
    }

    @Test func theRightCode_reportsCompletedOnce() async {
        let transport = ScriptedPhoneCodeTransport()
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.submit("123456")
        #expect(model(sut)?.isVerifying == true)
        await eventually { host.events == ["completed"] }
        #expect(transport.log == ["send email:2", "verify 123456"])
        #expect(host.events == ["completed"])
    }

    @Test func aWrongCode_staysOnTheScreen_flagged() async {
        let sut = session(ScriptedPhoneCodeTransport(verify: [.success(.rejected(canResend: true))]))
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.submit("000000")
        await eventually { model(sut)?.isCodeRejected == true }
        #expect(model(sut)?.isVerifying == false)
        #expect(host.events.isEmpty)
    }

    @Test func resend_sendsANewCode_withoutLeavingTheScreen() async {
        let transport = ScriptedPhoneCodeTransport()
        let sut = session(transport)
        sut.start()
        await eventually { model(sut) != nil }

        model(sut)?.resend()
        #expect(model(sut) != nil, "a resend keeps the code screen up")
        await eventually { transport.log.count == 2 }
        #expect(transport.log == ["send email:2", "send email:2"])
    }

    @Test func switchingAndCancelling_goThroughTheCore() async {
        let sut = session(ScriptedPhoneCodeTransport())
        sut.start()
        await eventually { model(sut) != nil }
        model(sut)?.switchFactor()
        model(sut)?.cancel()
        #expect(host.events == ["switch", "cancel"])
    }

    @Test func canSwitch_followsTheCore() async {
        host.canSwitch = true
        let sut = session(ScriptedPhoneCodeTransport())
        sut.start()
        await eventually { model(sut) != nil }
        #expect(model(sut)?.canSwitch == true)
    }

    // MARK: The factor

    private func factor(_ transport: ScriptedPhoneCodeTransport, cooldown: Int = 60) -> EmailCodeFactor {
        EmailCodeFactor(transport: transport, policy: EmailCodePolicy(resendCooldownSeconds: cooldown))
    }

    private func newSession(_ factor: EmailCodeFactor) -> MfaFactorSession {
        factor.makeSession(for: offer, host: host, environment: MfaFactorEnvironment(clock: clock))
    }

    /// The wait belongs to the factor, not to a session: coming back to an address that was just sent a code shows that
    /// code's screen again instead of sending another.
    @Test func comingBackToAnAddress_showsTheCodeSentEarlier_insteadOfSendingAnother() async {
        let transport = ScriptedPhoneCodeTransport()
        let sut = factor(transport)

        let first = newSession(sut)
        first.start()
        await eventually { first.model != nil }
        first.deactivate()

        let second = newSession(sut)
        second.start()
        #expect(second.model != nil, "the earlier code is shown at once")
        await settle()
        #expect(transport.log == ["send email:2"], "no second code went out")
    }

    @Test func theRow_namesTheAddress_andTheKindOfFactor() {
        let sut = factor(ScriptedPhoneCodeTransport())
        let named = sut.row(for: offer, messages: .default)
        #expect(named.title == "s***@atko.email")
        #expect(named.subtitle == "Email")
        #expect(named.icon == "email")

        let unnamed = sut.row(for: scriptedOffer("email:0", factor: .email), messages: .default)
        #expect(unnamed.title == "Email")
        #expect(unnamed.subtitle == "Get a code by email.")
    }

    @Test func theFactor_isRankedAfterThePhoneCodes() {
        #expect(factor(ScriptedPhoneCodeTransport()).rank > 45, "after a texted (40) and a spoken (45) code")
    }

    @Test func theStandardScreen_isOnlyForTheFactorsOwnModel() {
        let sut = factor(ScriptedPhoneCodeTransport())
        #expect(sut.standardView(for: EmailCodeChallengeModel(address: "s***@atko.email"), messages: .default) != nil)
        #expect(sut.standardView(for: PhoneCodeChallengeModel(destination: "(4**)***-*900"), messages: .default) == nil)
    }

    // MARK: Copy and screens

    @Test func theWords_followTheAddress_andCanBeChanged() {
        let defaults = MfaMessages.default.emailCodeChallenge
        #expect(defaults.subtitle(address: "s***@atko.email") == "From s***@atko.email")
        #expect(defaults.subtitle(address: "") == "We emailed you a code.")

        let changed = MfaMessages.default.with {
            $0.emailCodeChallenge.description = { address in "Sent to \(address)" }
        }
        #expect(changed.emailCodeChallenge.subtitle(address: "a***@b.c") == "Sent to a***@b.c")
        #expect(MfaMessages.default.emailCodeChallenge.subtitle(address: "a***@b.c") == "From a***@b.c")
    }

    @Test func aCustomScreen_replacesTheFactorsScreen_throughItsTypedShortcut() {
        let screens = MfaScreens(emailCodeChallenge: .custom { (model: EmailCodeChallengeModel) in
            Text(model.address)
        })
        #expect(screens.factorViews[.email] != nil)
        #expect(screens.factorViews[.sms] == nil, "only the email screen is replaced")
        #expect(screens.factorViews[.email]?(EmailCodeChallengeModel(address: "s***@atko.email")) != nil)
        #expect(screens.factorViews[.email]?(PhoneCodeChallengeModel(destination: "x")) == nil)
    }
}
