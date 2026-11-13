@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
@MainActor
struct EmbeddedRecoveryCodeBindingTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let menu: [NextAction] = [
        .challengePush(index: 0, name: "iPhone"),
        .challengePhone(index: 0, identifier: "(4**)***-*900", deliveryMethods: [.text, .voice]),
        .verifyRecoveryCode
    ]

    @Test func theBinding_offersARecoveryCode_whenTheServerAsksForOne() {
        let offers = EmbeddedRecoveryCodeBinding().offers(in: menu)
        #expect(offers.map(\.id) == ["recovery_code:0"])
        #expect(offers.map(\.factor) == [.recoveryCode])
        #expect(offers.first?.label == nil, "there is nothing to pick: no device, no number")
    }

    @Test func theBinding_offersNothing_otherwise() {
        #expect(EmbeddedRecoveryCodeBinding().offers(in: Array(menu.dropLast())).isEmpty)
        #expect(EmbeddedRecoveryCodeBinding().offers(in: [.confirmRecoveryCode(newCode: "NEW")]).isEmpty)
    }

    @Test func theBinding_advertisesWhatARecoveryCodeNeeds() {
        #expect(EmbeddedRecoveryCodeBinding().capabilities == [.verifyRecoveryCode, .confirmRecoveryCode])
    }

    /// Last in the list: push, then the phone codes, then the recovery code.
    @Test func theRecoveryCode_isListedLast_withItsOwnWordsAndIcon() {
        let context = AdditionalStepContext(nextActions: menu.reversed(), client: StubEmbeddedAuthClient(),
                                            credentialsDelivery: StubCredentialsDelivery())
        let session = EmbeddedMfaStep().makeSession(context: context, delegate: IgnoringDelegate())
        let controller = (session as? EmbeddedMfaSession)?.controller
        controller?.start()
        guard case let .authenticatorList(list)? = controller?.step else { Issue.record("no list"); return }
        #expect(list.rows.map(\.factor) == [.push, .sms, .voice, .recoveryCode])
        #expect(list.rows.last?.title == "Recovery code")
        #expect(list.rows.last?.subtitle == "Use your recovery code.")
        #expect(list.rows.last?.icon == "code")
    }
}

@MainActor
private final class IgnoringDelegate: AdditionalStepDelegate {
    func additionalStepDidFinish(_ result: AdditionalStepResult) {}
    func additionalStepRequestedRestart() {}
}

/// What each answer of the server becomes.
@Suite
@MainActor
struct EmbeddedRecoveryCodeTransportTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()
    private let gate = EmbeddedRequestGate()

    private func transport(menu: @escaping ([NextAction]) -> [MfaFactorOffer] = { _ in [] })
        -> (EmbeddedRecoveryCodeTransport, EmbeddedMfaStager) {
        let stager = EmbeddedMfaStager(delivery: store)
        return (EmbeddedRecoveryCodeTransport(client: client, stager: stager, gate: gate, menu: menu), stager)
    }

    // MARK: Checking the code

    @Test func verify_anAcceptedCode_returnsTheNewOne() async throws {
        client.verifyRecoveryCodeResults = [Fix.needs([Fix.confirmRecoveryCode(newCode: "NEW")])]
        #expect(try await transport().0.verify(code: "OLD") == .rotated(newCode: "NEW"))
        #expect(client.calls == [.verifyRecoveryCode(code: "OLD")])
    }

    @Test(arguments: ["invalid_code", "invalid_identifier_or_code"])
    func verify_aWrongCode_isRejected(_ subReason: String) async throws {
        client.verifyRecoveryCodeResults = [Fix.needs([Fix.verifyRecoveryCode], subReason: subReason)]
        #expect(try await transport().0.verify(code: "BAD") == .rejected)
    }

    @Test func verify_withoutANewCodeOrARejection_isUnexpected() async {
        client.verifyRecoveryCodeResults = [Fix.needs([Fix.challengePush])]
        await #expect(throws: MfaError.unexpected(nil)) { try await transport().0.verify(code: "OLD") }
    }

    @Test func verify_thatClosesTheLoop_isUnexpected() async {
        client.verifyRecoveryCodeResults = [nil]
        await #expect(throws: MfaError.unexpected(nil)) { try await transport().0.verify(code: "OLD") }
    }

    @Test func verify_withoutAConnection_isANetworkError() async {
        client.verifyRecoveryCodeResults = [Fix.network]
        await #expect(throws: MfaError.network) { try await transport().0.verify(code: "OLD") }
    }

    @Test func verify_tooManyAttempts_endsTheFlow() async {
        client.verifyRecoveryCodeResults = [Fix.terminal("too_many_requests", description: "too_many_attempts",
                                                         statusCode: 429)]
        await #expect(throws: MfaError.tooManyAttempts) { try await transport().0.verify(code: "OLD") }
    }

    // MARK: Confirming

    @Test func confirm_stagesTheCredentials_butDoesNotHandThemOver() async throws {
        client.confirmRecoveryCodeResults = [.success(Credentials(accessToken: "recovery"))]
        let (sut, stager) = transport()
        #expect(try await sut.confirm() == .verified)
        #expect(client.calls == [.confirmRecoveryCode])
        #expect(store.delivered.isEmpty, "staged, not yet handed over: the Core decides")
        try stager.commit()
        #expect(store.delivered.map(\.accessToken) == ["recovery"])
    }

    @Test func confirm_thenAnotherFactor_readsTheWholeMenu() async throws {
        let next = [MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)]
        client.confirmRecoveryCodeResults = [.failure(Fix.needs([Fix.challengePush]))]
        #expect(try await transport(menu: { _ in next }).0.confirm() == .anotherFactor(next))
    }

    @Test func confirm_withAnyOtherContinuation_isUnexpected() async {
        client.confirmRecoveryCodeResults = [.failure(Fix.needs([Fix.verifyRecoveryCode], subReason: "invalid_code"))]
        await #expect(throws: MfaError.unexpected(nil)) { try await transport().0.confirm() }
    }

    @Test func confirm_withoutAConnection_isANetworkError() async {
        client.confirmRecoveryCodeResults = [.failure(Fix.network)]
        await #expect(throws: MfaError.network) { try await transport().0.confirm() }
    }

    // MARK: A request that waited for its turn

    private final class Latch {
        var continuation: CheckedContinuation<Void, Never>?
    }

    /// Behind another request of the sign-in, and the user left before its turn: the code must not be used up.
    @Test func aCheckThatNobodyWantsAnyMore_isNeverSent() async throws {
        let latch = Latch()
        let occupant = Task { try await gate.run { await withCheckedContinuation { latch.continuation = $0 } } }
        await eventually { latch.continuation != nil }

        var wanted = true
        let isWanted: () -> Bool = { wanted }
        let sut = transport().0
        let queued = Task { try await sut.verify(code: "OLD", while: isWanted) }
        await settle()
        wanted = false
        latch.continuation?.resume()
        _ = try await occupant.value

        await #expect(throws: CancellationError.self) { try await queued.value }
        #expect(client.calls.isEmpty, "the old code is still good")
    }
}
