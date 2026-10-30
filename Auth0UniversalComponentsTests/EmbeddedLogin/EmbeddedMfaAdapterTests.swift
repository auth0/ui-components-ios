@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

@Suite
@MainActor
struct EmbeddedPushBindingTests {

    private let menu: [NextAction] = [
        .verifyOTP(channel: .totp, identifier: nil), .verifyRecoveryCode,
        .challengePhone(index: 0, identifier: "•••9239", deliveryMethods: [.text, .voice]),
        .challengeEmail(index: 0, identifier: "s***@o***"),
        .challengePush(index: 0, name: "iPhone"), .challengePush(index: 3, name: "iPad"),
        .identifyPhone, .unknown(rawAction: "action:x")
    ]

    @Test func theBinding_readsOnlyItsOwnFactorsOffers_fromTheServersMenu() {
        let offers = EmbeddedPushBinding().offers(in: menu)
        #expect(offers.map(\.id) == ["push:0", "push:3"])
        #expect(offers.map(\.label) == ["iPhone", "iPad"])
        #expect(offers.map(\.reference) == [0, 3], "the server's index, not a position in the list")
        #expect(offers.allSatisfy { $0.factor == .push })
    }

    @Test func aMenuWithoutPush_givesNoOffers() {
        #expect(EmbeddedPushBinding().offers(in: [.verifyOTP(channel: .totp, identifier: nil)]).isEmpty)
    }

    @Test func theBinding_advertisesWhatPushNeeds() {
        #expect(EmbeddedPushBinding().capabilities == [.challengePush, .verifyOob])
    }

    @Test func theAdditionalStep_advertisesTheUnionOfItsBindings_withoutRepeats() {
        #expect(EmbeddedMfaStep().capabilities == [.challengePush, .verifyOob])
        #expect(EmbeddedMfaStep(bindings: []).capabilities.isEmpty)
        #expect(EmbeddedMfaStep(bindings: [EmbeddedPushBinding(), EmbeddedPushBinding()]).capabilities
                == [.challengePush, .verifyOob])
    }

    /// With the login's own steps, this is what `authorize` is asked to route to: Email OTP, then Guardian push.
    @Test func withTheLoginsOwnSteps_theCapabilitiesAreEmailAndPush() {
        #expect(LiveEmbeddedAuthClient.firstFactorCapabilities + EmbeddedMfaStep().capabilities
                == [.identifyEmail, .challengeEmail, .verifyOTP, .challengePush, .verifyOob])
    }
}

@Suite
@MainActor
struct EmbeddedMfaStagerTests {

    private let store = StubCredentialsStore()
    private var sut: EmbeddedMfaStager { EmbeddedMfaStager(store: store) }

    @Test func staging_storesNothing_commitStoresOnce() throws {
        let stager = sut
        try stager.stage(Credentials(accessToken: "push"))
        #expect(store.stored.isEmpty)
        try stager.commit()
        #expect(store.stored.map(\.accessToken) == ["push"])
        #expect(throws: MfaError.unexpected(nil)) { try stager.commit() }
        #expect(store.stored.count == 1)
    }

    @Test func aKeychainFailure_isCredentialsNotSaved() throws {
        store.error = NSError(domain: "keychain", code: -25308)
        let stager = sut
        try stager.stage(Credentials())
        #expect(throws: MfaError.credentialsNotSaved) { try stager.commit() }
    }

    @Test func abandon_dropsWhatIsStaged() throws {
        let stager = sut
        try stager.stage(Credentials(accessToken: "push"))
        stager.abandon()
        #expect(throws: MfaError.unexpected(nil)) { try stager.commit() }
        #expect(store.stored.isEmpty)
    }

    @Test func aSignInAcceptedAfterTheFlowEnded_isNotStaged() {
        let stager = sut
        stager.abandon()
        #expect(throws: MfaError.cancelled) { try stager.stage(Credentials(accessToken: "late")) }
        #expect(throws: MfaError.unexpected(nil)) { try stager.commit() }
        #expect(store.stored.isEmpty)
    }
}

@Suite
struct EmbeddedMfaErrorsTests {

    @Test(arguments: [
        ("authorization_rejected", MfaError.rejected),
        ("challenge_expired", .tokenExpired),
        ("no_eligible_factors", .noEligibleFactors),
        ("too_many_wrong_otp_attempts", .tooManyAttempts)
    ])
    func terminalReasons_mapToTheirError(description: String, expected: MfaError) {
        let error = EmbeddedAuthFixtures.terminal("access_denied", description: description)
        #expect(EmbeddedMfaErrors.map(error) == expected)
    }

    @Test func sessionsThatEnded_areTokenInvalid() {
        #expect(EmbeddedMfaErrors.map(EmbeddedAuthFixtures.noActiveSession) == .tokenInvalid)
    }

    @Test func noConnection_isNetwork() {
        #expect(EmbeddedMfaErrors.map(EmbeddedAuthFixtures.network) == .network)
    }

    @Test func anIPBlock_carriesItsOwnWording() {
        let error = EmbeddedAuthFixtures.terminal("too_many_requests", description: "ip_blocked", statusCode: 429)
        #expect(EmbeddedMfaErrors.map(error) == .unexpected("Sign-in is temporarily blocked. Please try again later."))
    }
}

@Suite
@MainActor
struct EmbeddedPushTransportTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsStore()
    private let iPhone = MfaFactorOffer(id: "push:0", factor: .push, label: "iPhone", reference: 0)
    private let menuOffer = scriptedOffer("push:9", factor: .push, label: "menu")

    private func make() -> (EmbeddedPushTransport, EmbeddedMfaStager) {
        let stager = EmbeddedMfaStager(store: store)
        return (EmbeddedPushTransport(client: client, stager: stager, menu: { [menuOffer] _ in [menuOffer] }), stager)
    }

    // MARK: Sending

    @Test func sendPush_usesTheOffersReference_andReportsTheServersInterval() async throws {
        client.challengePushResults = [Fix.needs([Fix.verifyOob(pollInMs: 3_000), Fix.challengePush])]
        let ipad = MfaFactorOffer(id: "push:2", factor: .push, label: "iPad", reference: 2)
        let pending = try await make().0.sendPush(to: ipad)
        #expect(client.calls == [.challengePush(index: 2)])
        #expect(pending == PushPending(retryAfterMs: 3_000, canResend: true))
    }

    @Test func sendPush_withoutAnApprovalStep_isUnexpected() async {
        client.challengePushResults = [Fix.needs([Fix.verifyTOTP])]
        await #expect(throws: MfaError.unexpected(nil)) { try await make().0.sendPush(to: iPhone) }
    }

    @Test func sendPush_whenTheLoopClosesWithoutAnApproval_isUnexpected() async {
        client.challengePushResults = [nil]
        await #expect(throws: MfaError.unexpected(nil)) { try await make().0.sendPush(to: iPhone) }
    }

    @Test func sendPush_offline_isNetwork() async {
        client.challengePushResults = [Fix.network]
        await #expect(throws: MfaError.network) { try await make().0.sendPush(to: iPhone) }
    }

    @Test func sendPush_withoutAReference_isUnexpected() async {
        await #expect(throws: MfaError.unexpected(nil)) {
            try await make().0.sendPush(to: MfaFactorOffer(id: "push:x", factor: .push, label: nil))
        }
        #expect(client.calls.isEmpty)
    }

    // MARK: Checking

    @Test func check_pendingAndSlowDown_carryTheInterval() async throws {
        client.verifyOobResults = [
            .failure(Fix.needs([Fix.verifyOob(pollInMs: 3_000)], subReason: "authorization_pending")),
            .failure(Fix.needs([Fix.verifyOob(pollInMs: 4_000)], subReason: "slow_down"))
        ]
        let transport = make().0
        #expect(try await transport.checkApproval() == .pending(retryAfterMs: 3_000, canResend: false))
        #expect(try await transport.checkApproval() == .slowDown(retryAfterMs: 4_000, canResend: false))
    }

    /// The server stops offering the push at its resend limit; every answer says again whether it can be resent.
    @Test func check_saysWhetherThePushCanStillBeResent() async throws {
        client.verifyOobResults = [
            .failure(Fix.needs([Fix.verifyOob(pollInMs: 3_000), Fix.challengePush],
                               subReason: "authorization_pending")),
            .failure(Fix.needs([Fix.verifyOob(pollInMs: 3_000)], subReason: "authorization_pending"))
        ]
        let transport = make().0
        #expect(try await transport.checkApproval() == .pending(retryAfterMs: 3_000, canResend: true))
        #expect(try await transport.checkApproval() == .pending(retryAfterMs: 3_000, canResend: false))
    }

    @Test func check_approval_onlyStages_theCoreDecidesWhenToStore() async throws {
        client.verifyOobResults = [.success(Credentials(accessToken: "push"))]
        let (transport, stager) = make()
        #expect(try await transport.checkApproval() == .approved)
        #expect(store.stored.isEmpty)
        try stager.commit()
        #expect(store.stored.map(\.accessToken) == ["push"])
    }

    @Test func check_approvedAndAnotherFactorIsNeeded_usesTheWholeMenu() async throws {
        client.verifyOobResults = [.failure(Fix.needs([Fix.challengePush]))]
        #expect(try await make().0.checkApproval() == .anotherFactor([menuOffer]))
    }

    @Test(arguments: [
        ("authorization_rejected", MfaError.rejected),
        ("challenge_expired", .tokenExpired)
    ])
    func check_terminalAnswers_throwTheirError(description: String, expected: MfaError) async {
        client.verifyOobResults = [.failure(Fix.terminal("access_denied", description: description))]
        await #expect(throws: expected) { try await make().0.checkApproval() }
    }

    @Test func anApprovalThatArrivesAfterTheFlowEnded_isNotStaged() async {
        client.verifyOobResults = [.success(Credentials(accessToken: "late"))]
        let (transport, stager) = make()
        stager.abandon()
        await #expect(throws: MfaError.cancelled) { try await transport.checkApproval() }
        #expect(store.stored.isEmpty)
    }
}

/// The adapter is asked for a session every time the login needs a step, so it must keep nothing between them.
@Suite
@MainActor
struct EmbeddedMfaStepTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let clock = RecordingMfaClock()

    private func context(_ client: StubEmbeddedAuthClient, _ store: StubCredentialsStore) -> AdditionalStepContext {
        AdditionalStepContext(nextActions: [.challengePush(index: 0, name: "iPhone")], client: client,
                              credentialsStore: store)
    }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }

    @Test func oneProvider_runsSeveralIndependentSessions() async {
        let provider = EmbeddedMfaStep(clock: clock)
        let first = StubEmbeddedAuthClient()
        let firstStore = StubCredentialsStore()
        first.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        clock.suspends = true
        let firstDelegate = RecordingAdditionalStepDelegate()
        let firstSession = provider.makeSession(context: context(first, firstStore), delegate: firstDelegate)
        firstSession.start()
        await eventually { first.calls.contains(.challengePush(index: 0)) }
        firstSession.cancel()
        await firstSession.cancelAndWait()
        #expect(firstDelegate.results == [.cancelled])

        // A second run on the same provider, over a different sign-in, is not affected by the first.
        clock.suspends = false
        let second = StubEmbeddedAuthClient()
        let secondStore = StubCredentialsStore()
        second.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        second.verifyOobResults = [.success(Credentials(accessToken: "second"))]
        let secondDelegate = RecordingAdditionalStepDelegate()
        let secondSession = provider.makeSession(context: context(second, secondStore), delegate: secondDelegate)
        secondSession.start()
        await eventually { !secondDelegate.results.isEmpty }

        #expect(secondDelegate.results == [.completed])
        #expect(secondStore.stored.map(\.accessToken) == ["second"])
        #expect(firstStore.stored.isEmpty, "the first sign-in was cancelled and stays unstored")
        #expect(firstSession !== secondSession)
    }

    @Test func severalSessionsMayBeAliveTogether_withoutSharingCredentials() async {
        let provider = EmbeddedMfaStep(clock: clock)
        var stores: [StubCredentialsStore] = []
        var delegates: [RecordingAdditionalStepDelegate] = []
        var sessions: [AdditionalStepSession] = []
        for token in ["one", "two"] {
            let client = StubEmbeddedAuthClient()
            let store = StubCredentialsStore()
            client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
            client.verifyOobResults = [.success(Credentials(accessToken: token))]
            let delegate = RecordingAdditionalStepDelegate()
            sessions.append(provider.makeSession(context: context(client, store), delegate: delegate))
            stores.append(store)
            delegates.append(delegate)
        }
        sessions.forEach { $0.start() }
        await eventually { delegates.allSatisfy { !$0.results.isEmpty } }
        #expect(stores.map { $0.stored.map(\.accessToken) } == [["one"], ["two"]])
    }

    @Test func theAppsErrorHandler_isSharedByEveryRun() async {
        let provider = EmbeddedMfaStep(clock: clock)
        var reported: [MfaError] = []
        provider.errorHandler = { reported.append($0) }
        for _ in 0..<2 {
            let client = StubEmbeddedAuthClient()
            client.challengePushResults = [Fix.network]
            let delegate = RecordingAdditionalStepDelegate()
            let session = provider.makeSession(context: context(client, StubCredentialsStore()), delegate: delegate)
            session.start()
            await eventually { !delegate.results.isEmpty }
        }
        #expect(reported == [.network, .network])
    }
}
