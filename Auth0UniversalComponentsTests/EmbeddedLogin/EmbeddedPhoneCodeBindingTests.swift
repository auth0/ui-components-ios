@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
@MainActor
struct EmbeddedPhoneCodeBindingTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let menu: [NextAction] = [
        .challengePush(index: 0, name: "iPhone"),
        .challengePhone(index: 0, identifier: "(4**)***-*900", deliveryMethods: [.text, .voice]),
        .challengePhone(index: 1, identifier: "(5**)***-*111", deliveryMethods: [.voice]),
        .challengePhone(index: 2, identifier: "(6**)***-*222", deliveryMethods: [.text]),
        .verifyOTP(channel: .sms, identifier: "+1***99"), .identifyPhone
    ]

    /// The text binding offers only phones that can take a text.
    @Test func theTextBinding_offersPhonesThatTakeTexts() {
        let offers = EmbeddedPhoneCodeBinding(delivery: .text).offers(in: menu)
        #expect(offers.map(\.id) == ["sms:0", "sms:2"])
        #expect(offers.map(\.label) == ["(4**)***-*900", "(6**)***-*222"])
        #expect(offers.map(\.reference) == [0, 2], "the server's index, not a position in the list")
        #expect(offers.allSatisfy { $0.factor == .sms })
    }

    /// The voice binding offers only phones the server can call, under their own ids.
    @Test func theVoiceBinding_offersPhonesThatTakeCalls() {
        let offers = EmbeddedPhoneCodeBinding(delivery: .voice).offers(in: menu)
        #expect(offers.map(\.id) == ["voice:0", "voice:1"])
        #expect(offers.map(\.label) == ["(4**)***-*900", "(5**)***-*111"])
        #expect(offers.map(\.reference) == [0, 1])
        #expect(offers.allSatisfy { $0.factor == .voice })
    }

    /// A server that hides digits with `X` gets them drawn as `*`, like the sign-in's phone screen.
    @Test(arguments: [PhoneCodeDelivery.text, .voice])
    func theBinding_showsHiddenDigitsAsAsterisks(_ delivery: PhoneCodeDelivery) {
        let menu: [NextAction] = [
            .challengePhone(index: 0, identifier: "+1XXXxxx900", deliveryMethods: [.text, .voice])
        ]
        #expect(EmbeddedPhoneCodeBinding(delivery: delivery).offers(in: menu).map(\.label) == ["+1******900"])
    }

    @Test(arguments: [PhoneCodeDelivery.text, .voice])
    func theBinding_advertisesWhatAPhoneCodeNeeds(_ delivery: PhoneCodeDelivery) {
        #expect(EmbeddedPhoneCodeBinding(delivery: delivery).capabilities == [.challengePhone, .verifyOTP])
    }

    /// Push comes first in the list: an approval on a registered device can't be phished, a phone code can. A text
    /// comes before a call to the same phone.
    @Test func push_isListedBeforeTheText_andTheTextBeforeTheCall() {
        let step = EmbeddedMfaStep()
        let client = StubEmbeddedAuthClient()
        let context = AdditionalStepContext(nextActions: [menu[1], menu[0]], client: client,
                                            credentialsDelivery: StubCredentialsDelivery())
        let session = step.makeSession(context: context, delegate: NoAdditionalStepDelegate())
        let controller = (session as? EmbeddedMfaSession)?.controller
        controller?.start()
        guard case let .authenticatorList(list)? = controller?.step else { Issue.record("no list"); return }
        #expect(list.rows.map(\.factor) == [.push, .sms, .voice])
        #expect(list.rows.dropFirst().map(\.title) == ["(4**)***-*900", "(4**)***-*900"])
        #expect(list.rows.dropFirst().map(\.subtitle) == ["Text message", "Voice call"])
        #expect(list.rows.dropFirst().map(\.icon) == ["sms", nil])
        #expect(list.rows.dropFirst().map(\.systemImage) == [nil, "phone"], "a handset for the call")
    }
}

@MainActor
private final class NoAdditionalStepDelegate: AdditionalStepDelegate {
    func additionalStepDidFinish(_ result: AdditionalStepResult) {}
    func additionalStepRequestedRestart() {}
}

@Suite
@MainActor
struct EmbeddedPhoneCodeTransportTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()
    private let offer = MfaFactorOffer(id: "sms:2", factor: .sms, label: "(4**)***-*900", reference: 2)

    private func transport(_ delivery: PhoneCodeDelivery = .text,
                           menu: @escaping ([NextAction]) -> [MfaFactorOffer] = { _ in [] })
        -> (EmbeddedPhoneCodeTransport, EmbeddedMfaStager) {
        let stager = EmbeddedMfaStager(delivery: store)
        return (EmbeddedPhoneCodeTransport(delivery: delivery, client: client, stager: stager,
                                           gate: EmbeddedRequestGate(), menu: menu), stager)
    }

    // MARK: Sending

    @Test func send_textsTheCodeToTheOffersPhone() async throws {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS, Fix.challengePhone(index: 2)])]
        let sent = try await transport().0.sendCode(to: offer)
        #expect(client.calls == [.challengePhone(index: 2, deliveryMethod: .text)])
        #expect(sent == PhoneCodeSent(canResend: true))
    }

    @Test func send_voice_callsThePhone_andWaitsForTheSpokenCode() async throws {
        client.challengePhoneResults = [Fix.needs([Fix.verifyVoice, Fix.challengePhone(index: 2)])]
        let sent = try await transport(.voice).0.sendCode(to: offer)
        #expect(client.calls == [.challengePhone(index: 2, deliveryMethod: .voice)])
        #expect(sent == PhoneCodeSent(canResend: true))
    }

    /// The server asking for the other channel's code means the request wasn't the one sent.
    @Test(arguments: [PhoneCodeDelivery.text, .voice])
    func send_answeredWithTheOtherChannelsPrompt_isUnexpected(_ delivery: PhoneCodeDelivery) async {
        client.challengePhoneResults = [Fix.needs([delivery == .text ? Fix.verifyVoice : Fix.verifySMS])]
        await #expect(throws: MfaError.unexpected(nil)) { try await transport(delivery).0.sendCode(to: offer) }
    }

    @Test func verify_voice_checksTheCodeTheSameWay() async throws {
        client.verifyOtpResults = [.success(Credentials(accessToken: "voice"))]
        #expect(try await transport(.voice).0.verify(code: "123456") == .verified)
        #expect(client.calls == [.verifyOtp(code: "123456", type: .oob)])
    }

    @Test func send_withoutThePhoneOnOffer_cantBeResent() async throws {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        #expect(try await transport().0.sendCode(to: offer) == PhoneCodeSent(canResend: false))
    }

    @Test func send_withoutACodePrompt_isUnexpected() async {
        client.challengePhoneResults = [Fix.needs([Fix.challengePush])]
        await #expect(throws: MfaError.unexpected(nil)) { try await transport().0.sendCode(to: offer) }
    }

    @Test func send_thatClosesTheLoop_isUnexpected() async {
        client.challengePhoneResults = [nil]
        await #expect(throws: MfaError.unexpected(nil)) { try await transport().0.sendCode(to: offer) }
    }

    @Test func send_rateLimited_isTooManyAttempts() async {
        client.challengePhoneResults = [Fix.terminal("too_many_requests", description: "too_many_attempts",
                                                     statusCode: 429)]
        await #expect(throws: MfaError.tooManyAttempts) { try await transport().0.sendCode(to: offer) }
    }

    // MARK: Checking

    @Test func verify_acceptsTheCode_andStagesTheCredentials() async throws {
        client.verifyOtpResults = [.success(Credentials(accessToken: "sms"))]
        let (sut, stager) = transport()
        #expect(try await sut.verify(code: "123456") == .verified)
        #expect(client.calls == [.verifyOtp(code: "123456", type: .oob)])
        #expect(store.delivered.isEmpty, "staged, not yet handed over: the Core decides")
        try stager.commit()
        #expect(store.delivered.map(\.accessToken) == ["sms"])
    }

    @Test(arguments: ["invalid_code", "invalid_identifier_or_code"])
    func verify_aWrongCode_isRejected(_ subReason: String) async throws {
        client.verifyOtpResults = [.failure(Fix.needs([Fix.verifySMS, Fix.challengePhone()], subReason: subReason))]
        #expect(try await transport().0.verify(code: "000000") == .rejected(canResend: true))
    }

    @Test func verify_thenAnotherFactor_readsTheWholeMenu() async throws {
        let next = [MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)]
        client.verifyOtpResults = [.failure(Fix.needs([Fix.challengePush]))]
        #expect(try await transport(menu: { _ in next }).0.verify(code: "123456") == .anotherFactor(next))
    }

    @Test func verify_tooManyWrongCodes_endsTheFlow() async {
        client.verifyOtpResults = [.failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))]
        await #expect(throws: MfaError.tooManyAttempts) { try await transport().0.verify(code: "000000") }
    }
}

/// One request at a time per sign-in, across every factor.
@Suite
@MainActor
struct EmbeddedRequestGateTests {

    @Test func aSecondCall_waitsForTheFirst_andCallsRunInOrder() async throws {
        let gate = EmbeddedRequestGate()
        let recorder = GateRecorder()

        let first = Task {
            try await gate.run {
                recorder.log.append("first started")
                await withCheckedContinuation { recorder.release = $0 }
                recorder.log.append("first done")
            }
        }
        await eventually { recorder.release != nil }
        let second = Task { try await gate.run { recorder.log.append("second") } }
        let third = Task { try await gate.run { recorder.log.append("third") } }
        await settle()
        #expect(recorder.log == ["first started"], "the others wait while the first is on its way")

        recorder.release?.resume()
        _ = try await (first.value, second.value, third.value)
        #expect(recorder.log == ["first started", "first done", "second", "third"])
    }

    @Test func aCallThatThrows_stillHandsTheTurnOn() async throws {
        let gate = EmbeddedRequestGate()
        await #expect(throws: MfaError.network) { try await gate.run { throw MfaError.network } }
        #expect(try await gate.run { "next" } == "next")
    }

    /// A push check still on its way when the user switches to a texted code: the text waits for it.
    @Test func aTextSend_waitsForAPushCheckOfTheSameSignIn() async throws {
        let client = HoldingEmbeddedAuthClient()
        let gate = EmbeddedRequestGate()
        let stager = EmbeddedMfaStager(delivery: StubCredentialsDelivery())
        let push = EmbeddedPushTransport(client: client, stager: stager, gate: gate, menu: { _ in [] })
        let sms = EmbeddedPhoneCodeTransport(delivery: .text, client: client, stager: stager, gate: gate,
                                             menu: { _ in [] })

        let check = Task { try? await push.checkApproval() }
        await eventually { client.isHoldingCheck }
        let send = Task {
            try await sms.sendCode(to: MfaFactorOffer(id: "sms:0", factor: .sms, label: nil, reference: 0))
        }
        await settle()
        #expect(client.calls == ["verifyOob"], "the text is not sent while the check is on its way")

        client.releaseCheck()
        _ = await check.value
        _ = try await send.value
        #expect(client.calls == ["verifyOob", "challengePhone"])
    }
}

@MainActor
private final class GateRecorder {
    var log: [String] = []
    var release: CheckedContinuation<Void, Never>?
}

/// Holds a push check on the wire until released; answers a phone challenge with a code prompt.
@MainActor
private final class HoldingEmbeddedAuthClient: EmbeddedAuthClient {
    private typealias Fix = EmbeddedAuthFixtures

    private(set) var calls: [String] = []
    private var held: CheckedContinuation<Void, Never>?
    var isHoldingCheck: Bool { held != nil }

    func releaseCheck() {
        held?.resume()
        held = nil
    }

    func verifyOob() async throws -> Credentials {
        calls.append("verifyOob")
        await withCheckedContinuation { held = $0 }
        throw Fix.needs([Fix.verifyOob()], subReason: "authorization_pending")
    }

    func challengePhone(index: Int, deliveryMethod: PhoneDeliveryMethod) async throws {
        calls.append("challengePhone")
        throw Fix.needs([Fix.verifySMS])
    }

    // The login's own steps aren't part of this.
    func authorize(connection: String) async throws { throw Fix.noActiveSession }
    func identify(_ identifier: String, type: IdentifierType) async throws { throw Fix.noActiveSession }
    func challengeEmail(index: Int) async throws { throw Fix.noActiveSession }
    func verifyOtp(_ code: String, type: OtpType) async throws -> Credentials { throw Fix.noActiveSession }
    func challengePush(index: Int) async throws { throw Fix.noActiveSession }
}
