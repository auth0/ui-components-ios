import Auth0
import Foundation
import Testing
@testable import Auth0UniversalComponents

/// Sign-up with a phone number, from the coordinator down to the SDK's calls, over `SessionAwareEmbeddedAuthClient`:
/// a number that takes texts and calls and asks which, one that takes only one of them, and a code that timed out.
@MainActor
@Suite struct SignupPhoneFlowTests {

    typealias Fixtures = EmbeddedAuthFixtures
    private let phone = SignupHarness.phone
    private let masked = SignupHarness.maskedPhone

    private func challenge(methods: [String]) -> [String: Any] {
        Fixtures.challengePhone(masked: masked, methods: methods)
    }

    /// A phone sign-up whose number takes `methods`, with a code to be sent once, and once more.
    private func harness(methods: [String]) -> SignupHarness {
        let harness = SignupHarness(kind: .phone)
        let script = harness.client.scripted
        script.identifyResults = [Fixtures.needs([challenge(methods: methods), Fixtures.identifyPhone])]
        script.challengePhoneResults = [
            Fixtures.needs([Fixtures.verifySMS, challenge(methods: methods), Fixtures.identifyPhone]),
            Fixtures.needs([Fixtures.verifySMS, challenge(methods: methods), Fixtures.identifyPhone])
        ]
        return harness
    }

    // MARK: The happy path

    @Test func aPhoneSignup_runsFromTheEntryToACreatedAccount() async {
        let harness = harness(methods: ["text", "voice"])
        let sut = harness.sut

        await sut.send(.start)
        #expect(sut.step == .collectIdentifier(.phone))

        await sut.send(.submitIdentifier(phone))
        guard case let .chooseDelivery(choice) = sut.step else { Issue.record("\(sut.step)"); return }
        #expect(choice.challenge.sentTo == "+1******4567", "the server's mask, not the number that was typed")
        #expect(choice.challenge.deliveries == [.text, .voice])
        #expect(!harness.client.calls.contains { if case .challengePhone = $0 { return true } else { return false } },
                "nothing is sent before the user chooses")

        await sut.send(.chooseDelivery(.text))
        guard case let .collectCode(code) = sut.step else { Issue.record("\(sut.step)"); return }
        #expect(code.delivery == .text)
        #expect(code.subtitle == "Sent to +1******4567")

        await sut.send(.submitCode("123456"))
        #expect(sut.step == .confirm)
        await sut.send(.confirm)
        #expect(sut.step == .created)
        #expect(harness.delivered.credentials.isEmpty)
        await sut.send(.finish)

        #expect(sut.step == .authenticated)
        #expect(harness.delivered.credentials.count == 1)
        #expect(harness.client.calls == [
            .authorize(connection: "db"), .signup, .identify("+15551234567", type: .phone),
            .challengePhone(index: 0, deliveryMethod: .text), .verifyOtp(code: "123456", type: .oob), .confirmSignup
        ])
    }

    // MARK: Text and voice

    @Test func choosingACall_sendsTheCodeByCall_andTheScreenSaysSo() async {
        let harness = harness(methods: ["text", "voice"])
        await harness.onTheCodeScreen(phone)

        await harness.sut.send(.chooseDelivery(.voice))

        guard case let .collectCode(code) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(code.delivery == .voice)
        #expect(code.subtitle == "Called +1******4567")
        #expect(harness.client.calls.last == .challengePhone(index: 0, deliveryMethod: .voice))
    }

    @Test func resend_goesTheWayTheUserChose() async {
        let harness = harness(methods: ["text", "voice"])
        await harness.onTheCodeScreen(phone)
        await harness.sut.send(.chooseDelivery(.voice))

        await harness.sut.send(.resend)

        let calls = harness.client.calls.filter { if case .challengePhone = $0 { return true } else { return false } }
        #expect(calls == [.challengePhone(index: 0, deliveryMethod: .voice),
                          .challengePhone(index: 0, deliveryMethod: .voice)])
    }

    @Test func aNumberThatOnlyTakesTexts_isNotAskedHow() async {
        let harness = harness(methods: ["text"])
        await harness.onTheCodeScreen(phone)

        guard case let .collectCode(code) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(code.delivery == .text)
        #expect(harness.client.calls.last == .challengePhone(index: 0, deliveryMethod: .text))
    }

    @Test func aNumberThatOnlyTakesCalls_isCalledWithoutBeingAsked() async {
        let harness = harness(methods: ["voice"])
        await harness.onTheCodeScreen(phone)

        guard case let .collectCode(code) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(code.delivery == .voice)
        #expect(code.subtitle == "Called +1******4567")
        #expect(!harness.client.calls.contains(.challengePhone(index: 0, deliveryMethod: .text)))
    }

    @Test func aWayTheNumberDoesntTake_isIgnored() async {
        let harness = harness(methods: ["text", "voice"])
        await harness.onTheCodeScreen(phone)
        let screen = harness.sut.step

        await harness.sut.send(.chooseDelivery(.email))

        #expect(harness.sut.step == screen)
    }

    @Test func choosingBeforeANumberIsAccepted_doesNothing() async {
        let harness = harness(methods: ["text", "voice"])
        await harness.sut.send(.start)

        await harness.sut.send(.chooseDelivery(.text))

        #expect(harness.sut.step == .collectIdentifier(.phone))
    }

    @Test func back_fromTheChoice_returnsToTheEntry_withTheNumberKept_andNothingSent() async {
        let harness = harness(methods: ["text", "voice"])
        await harness.onTheCodeScreen(phone)

        #expect(harness.sut.goBack() == .movedBack)

        #expect(harness.sut.step == .collectIdentifier(.phone))
        #expect(harness.sut.entered == phone)
        #expect(!harness.client.calls.contains(.challengePhone(index: 0, deliveryMethod: .text)))
    }

    @Test func aLostConnectionSendingTheCode_failsWithAWayToTryAgain_thatReturnsToTheChoice() async {
        let harness = harness(methods: ["text", "voice"])
        harness.client.scripted.challengePhoneResults = [Fixtures.network]
        await harness.onTheCodeScreen(phone)

        await harness.sut.send(.chooseDelivery(.text))

        guard case .failed(_, canRetry: true) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        await harness.sut.send(.retry)
        guard case .chooseDelivery = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
    }

    // MARK: Invalid number and wrong code

    @Test func anInvalidNumber_staysOnTheEntry_withTheMessage_andTheNextTryWorks() async {
        let harness = SignupHarness(kind: .phone)
        let script = harness.client.scripted
        script.identifyResults = [Fixtures.needs([Fixtures.identifyPhone], subReason: "invalid_phone"),
                                  Fixtures.needs([challenge(methods: ["text"]), Fixtures.identifyPhone])]
        await harness.sut.send(.start)

        await harness.sut.send(.submitIdentifier(phone))
        #expect(harness.sut.step == .collectIdentifier(.phone))
        #expect(harness.sut.inputError == .invalidPhone)
        #expect(harness.sut.inputError?.message(for: .phone) == "Please enter a valid phone number.")
        #expect(harness.sut.entered == phone, "what was typed comes back")

        await harness.sut.send(.submitIdentifier(phone))
        #expect(harness.sut.inputError == nil)
        guard case .collectCode = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
    }

    @Test func aWrongCode_staysOnTheScreen_andSaysItWasSentToThePhone() async {
        let harness = harness(methods: ["text"])
        harness.client.scripted.verifyOtpResults = [
            .failure(Fixtures.needs([Fixtures.verifySMS], subReason: "invalid_code"))]
        await harness.onTheCodeScreen(phone)

        await harness.sut.send(.submitCode("000000"))

        guard case let .collectCode(code) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(!code.isExpired)
        #expect(harness.sut.inputError?.message(for: .phone)
                == "Invalid code. Please double check your code that was sent to your phone.")
    }

    @Test func aNumberTheServerOffersNoCodeFor_saysSoInThePhonesWords() async {
        let harness = SignupHarness(kind: .phone)
        harness.client.scripted.identifyResults = [Fixtures.needs([Fixtures.identifyPhone])]
        await harness.sut.send(.start)

        await harness.sut.send(.submitIdentifier(phone))

        #expect(harness.sut.inputError == .codeNotSent)
        #expect(harness.sut.inputError?.message(for: .phone)
                == "We couldn't send your code. Please confirm the phone number is correct and try again.")
    }

    // MARK: A code that timed out

    /// The server ends the sign-up with the code. The screen stays, and the next code starts a new sign-up for the
    /// same number, by the way the user chose: against a client that fails every call on a dead session, as the SDK
    /// does.
    @Test func anExpiredCode_staysOnTheScreen_andANewCodeStartsTheSignupOver() async {
        let harness = harness(methods: ["text", "voice"])
        let script = harness.client.scripted
        script.verifyOtpResults = [.failure(Fixtures.terminal("access_denied", description: "challenge_expired"))]
        await harness.onTheCodeScreen(phone)
        await harness.sut.send(.chooseDelivery(.voice))

        await harness.sut.send(.submitCode("123456"))

        guard case let .collectCode(expired) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(expired.isExpired)
        #expect(harness.sut.inputError == .codeExpired)
        #expect(harness.sut.inputError?.message(for: .phone) == "The code expired. Send a new one to continue.")
        #expect(!harness.client.hasSession, "the SDK closed it with the code")

        // Nothing is checked while the code is expired.
        await harness.sut.send(.submitCode("123456"))
        let verifies = harness.client.calls.filter { if case .verifyOtp = $0 { return true } else { return false } }
        #expect(verifies.count == 1)

        script.authorizeResults = [Fixtures.needs([Fixtures.signup(email: nil, phone: true)])]
        script.signupResults = [Fixtures.needs([Fixtures.identifyPhone])]
        script.identifyResults = [Fixtures.needs([challenge(methods: ["text", "voice"]), Fixtures.identifyPhone])]
        script.challengePhoneResults = [Fixtures.needs([Fixtures.verifyVoice, challenge(methods: ["text", "voice"]),
                                                        Fixtures.identifyPhone])]
        await harness.sut.send(.resend)

        guard case let .collectCode(fresh) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(!fresh.isExpired)
        #expect(fresh.delivery == .voice, "the way the user chose, without asking again")
        #expect(harness.sut.inputError == nil)
        #expect(harness.client.calls.filter { $0 == .authorize(connection: "db") }.count == 2)
        #expect(harness.client.calls.filter { $0 == .identify("+15551234567", type: .phone) }.count == 2)
        #expect(harness.client.calls.last == .challengePhone(index: 0, deliveryMethod: .voice))
    }

    @Test func anExpiredCode_thatCantBeReplaced_failsWithAWayToTryAgain() async {
        let harness = harness(methods: ["text"])
        let script = harness.client.scripted
        script.verifyOtpResults = [.failure(Fixtures.terminal("access_denied", description: "challenge_expired"))]
        await harness.onTheCodeScreen(phone)
        await harness.sut.send(.submitCode("123456"))
        script.authorizeResults = [Fixtures.network]

        await harness.sut.send(.resend)

        guard case .failed(_, canRetry: true) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
    }

    /// An email's expired code still ends the sign-up: only a phone replaces it from the code screen.
    @Test func anExpiredEmailCode_stillEndsTheSignup() async {
        let harness = SignupHarness()
        harness.client.scripted.verifyOtpResults = [
            .failure(Fixtures.terminal("access_denied", description: "challenge_expired"))]
        await harness.onTheCodeScreen()

        await harness.sut.send(.submitCode("123456"))

        #expect(harness.sut.step == .failed(message: SignupFailure.codeExpired.message(for: .email), canRetry: false))
    }

    // MARK: What the connection asks for

    @Test func aRequiredPhone_besideAnOptionalEmail_startsOnThePhone() async {
        let harness = SignupHarness(kind: .phone)
        harness.client.scripted.authorizeResults = [Fixtures.needs([Fixtures.signup(email: false, phone: true)])]
        harness.client.scripted.signupResults = [Fixtures.needs([Fixtures.identifyEmail, Fixtures.identifyPhone])]

        await harness.sut.send(.start)

        #expect(harness.sut.step == .collectIdentifier(.phone))
    }

    @Test func aRequiredEmail_besideAnOptionalPhone_startsOnTheEmail() async {
        let harness = SignupHarness()
        harness.client.scripted.authorizeResults = [Fixtures.needs([Fixtures.signup(email: true, phone: false)])]
        harness.client.scripted.signupResults = [Fixtures.needs([Fixtures.identifyEmail, Fixtures.identifyPhone])]

        await harness.sut.send(.start)

        #expect(harness.sut.step == .collectIdentifier(.email))
    }

    @Test func back_fromThePhoneCodeScreen_returnsToTheEntry_withTheNumberKept() async {
        let harness = harness(methods: ["text"])
        await harness.onTheCodeScreen(phone)

        #expect(harness.sut.goBack() == .movedBack)

        #expect(harness.sut.step == .collectIdentifier(.phone))
        #expect(harness.sut.entered == phone)
    }
}

@Suite struct SignupPhoneModelTests {

    @Test func theMenuAfterSignup_asksForThePhone() {
        let menu = SignupMenu([.identifyPhone])
        #expect(menu.askedFor == [.phone])
        #expect(menu.challenge == nil)
    }

    @Test func aPhoneChallenge_keepsTheMask_andTheWaysTheNumberTakes_textFirst() {
        let menu = SignupMenu([.challengePhone(index: 2, identifier: "+1XXXXXX4567", deliveryMethods: [.voice, .text]),
                               .identifyPhone])
        #expect(menu.challenge == SignupChallenge(index: 2, sentTo: "+1******4567",
                                                  deliveries: [.text, .voice]))
        #expect(menu.challenge?.firstDelivery == .text)
    }

    @Test func aNumberThatOnlyTakesCalls_isCalledFirst() {
        let challenge = SignupChallenge(index: 0, deliveries: [.voice])
        #expect(challenge.firstDelivery == .voice)
    }

    @Test func aChallengeWithNoWayToSendIt_hasNoFirstDelivery() {
        #expect(SignupChallenge(index: 0, deliveries: []).firstDelivery == nil)
    }

    @Test func preferringAKind_asksForItFirst() {
        let actions: [NextAction] = [.identifyEmail, .identifyPhone]
        #expect(SignupMenu(actions).askedFor == [.email, .phone])
        #expect(SignupMenu(actions, preferring: [.phone]).askedFor == [.phone, .email])
    }
}

@Suite struct SignupPhoneWordsTests {

    private let phone = SignupHarness.phone
    private let both = SignupChallenge(index: 0, sentTo: "+1******4567", deliveries: [.text, .voice])

    @Test func theSubtitle_saysWhereTheCodeWent_andHow() {
        let texted = SignupCodeStep(identifier: phone, challenge: both, delivery: .text)
        let called = SignupCodeStep(identifier: phone, challenge: both, delivery: .voice)
        #expect(texted.subtitle == "Sent to +1******4567")
        #expect(called.subtitle == "Called +1******4567")
    }

    @Test func anEmailSubtitle_showsWhatWasTyped() {
        let email = SignupHarness.email
        let code = SignupCodeStep(identifier: email, challenge: SignupChallenge(index: 1), delivery: .email)
        #expect(code.subtitle == "Sent to sarah.doe@example.com")
    }
}
