@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// Guardian push through the whole stack, composed the way `EmbeddedLoginView` composes it: the real login
/// interactor and coordinator, the MFA adapter, the Core and the push factor, against the scripted SDK client.
/// Case IDs match docs/embedded-login-guardian-push-test-cases.md.
@Suite
@MainActor
struct EmbeddedMfaEndToEndTests { // swiftlint:disable:this type_body_length

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sudhanshu.vohra@okta.com"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsStore()
    private let clock = RecordingMfaClock()

    private let secondPush: [String: Any] = [
        "action": "action:challenge:push:v1", "index": 1, "name": "Sudhanshu's iPad"
    ]

    /// Scripts discovery → email → challenge, then answers the email code with `afterTheCode`.
    private func signIn(afterTheCode: EmbeddedAuthError,
                        handler: ((MfaError) -> Void)? = nil) async -> LoginFlowCoordinator {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyOtpResults = [.failure(afterTheCode)]
        let provider = EmbeddedMfaStep(clock: clock)
        provider.errorHandler = handler
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsStore: store, connection: "email")
        let sut = LoginFlowCoordinator(interactor: interactor, additionalStep: provider)
        await sut.send(.start)
        await sut.send(.submitIdentifier(email))
        await sut.send(.submitOTP(code: "111111"))
        return sut
    }

    /// The tenant asks for more than the email code and lists `menu`.
    private func menu(_ entries: [[String: Any]]) -> EmbeddedAuthError { Fix.needs(entries) }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }

    private func mfaStep(_ sut: LoginFlowCoordinator) -> MfaStep? {
        (sut.additionalStep as? EmbeddedMfaSession)?.controller.step
    }

    private func error(_ sut: LoginFlowCoordinator) -> MfaError? {
        if case let .error(model)? = mfaStep(sut) { return model.error }
        return nil
    }

    private func pushModel(_ sut: LoginFlowCoordinator) -> PushChallengeModel? {
        if case let .factor(step)? = mfaStep(sut) { return step.model as? PushChallengeModel }
        return nil
    }

    private func list(_ sut: LoginFlowCoordinator) -> AuthenticatorListModel? {
        if case let .authenticatorList(model)? = mfaStep(sut) { return model }
        return nil
    }

    private var pushCalls: [StubEmbeddedAuthClient.Call] {
        client.calls.filter { call in
            switch call {
            case .challengePush, .verifyOob: return true
            default: return false
            }
        }
    }

    // MARK: Entry

    /// GP-01: one Guardian device, so the push goes out straight away.
    @Test func gp01_singleDevice_sendsThePushAtOnce() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob(pollInMs: 2_000)])]
        client.verifyOobResults = [
            .failure(Fix.needs([Fix.verifyOob(pollInMs: 2_000)], subReason: "authorization_pending")),
            .success(Credentials(accessToken: "push"))
        ]

        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { sut.step == .authenticated }

        #expect(sut.step == .authenticated)
        #expect(pushCalls == [.challengePush(index: 0), .verifyOob, .verifyOob])
        #expect(store.stored.map(\.accessToken) == ["push"])
    }

    /// GP-02: several Guardian devices, so the user picks one and the push goes to that index.
    @Test func gp02_severalDevices_sendToThePickedOne() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]

        let sut = await signIn(afterTheCode: menu([Fix.challengePush, secondPush]))
        guard let rows = list(sut) else { Issue.record("no list"); return }
        #expect(rows.rows.map(\.title) == ["Sudhanshu's iPhone", "Sudhanshu's iPad"])
        #expect(rows.rows.map(\.subtitle) == ["Push notification", "Push notification"])
        #expect(rows.header == .challenge)
        #expect(pushCalls.isEmpty)

        rows.select("push:1")
        await eventually { sut.step == .authenticated }

        #expect(pushCalls.first == .challengePush(index: 1))
    }

    /// GP-03: the menu has nothing this flow can run: the "verification method not available" screen shows.
    @Test func gp03_noPushOnOffer_isTerminal() async {
        let sut = await signIn(afterTheCode: menu([Fix.verifyTOTP, Fix.verifySMS]))

        #expect(sut.step == .additionalStepUnavailable)
        #expect(pushCalls.isEmpty)
        #expect(store.stored.isEmpty)
    }

    /// The same, when the app set `onMfaError`: it is told, and routes the user (say, to Universal Login).
    @Test func gp03_withAHandler_theAppIsToldInstead() async {
        var reported: [MfaError] = []
        let sut = await signIn(afterTheCode: menu([Fix.verifyTOTP]), handler: { reported.append($0) })

        #expect(reported == [.noEligibleFactors])
        #expect(sut.step == .additionalStep)
        #expect(pushCalls.isEmpty)
    }

    /// GP-06: more is required but the user has no eligible factor; same outcome, not a retry on a dead session.
    @Test func gp06_noEligibleFactors_isTheSameTerminalState() async {
        let sut = await signIn(afterTheCode: Fix.terminal("access_denied", description: "no_eligible_factors"))
        #expect(sut.step == .additionalStepUnavailable)
    }

    /// GP-04: nothing more needed, so the user is signed in without an additional step.
    @Test func gp04_noMFA_signsInDirectly() async {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "email"))]
        let sut = LoginFlowCoordinator(interactor: Auth0EmbeddedAuthInteractor(client: client, credentialsStore: store,
                                                                               connection: "email"),
                                       additionalStep: EmbeddedMfaStep(clock: clock))
        await sut.send(.start)
        await sut.send(.submitIdentifier(email))
        await sut.send(.submitOTP(code: "111111"))

        #expect(sut.step == .authenticated)
        #expect(sut.additionalStep == nil)
    }

    /// GP-05: a wrong email code stays on the code screen; no additional step is involved.
    @Test func gp05_wrongEmailCode_staysInline() async {
        let sut = await signIn(afterTheCode: Fix.needs([Fix.verifyEmail], subReason: "invalid_identifier_or_code"))

        #expect(sut.step == .collectOTPCode(identifier: email))
        #expect(sut.inputError == .invalidCode)
        #expect(pushCalls.isEmpty)
    }

    // MARK: Approval

    /// GP-09 / GP-10 / GP-11: terminal answers end the flow with their own error.
    @Test func gp09_gp10_gp11_terminalAnswers() async {
        let cases: [(EmbeddedAuthError, MfaError)] = [
            (Fix.terminal("access_denied", description: "authorization_rejected"), .rejected),
            (Fix.terminal("access_denied", description: "challenge_expired"), .tokenExpired),
            (Fix.noActiveSession, .tokenInvalid)
        ]
        for (serverError, expected) in cases {
            client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
            client.verifyOobResults = [.failure(serverError)]

            let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
            await eventually { error(sut) == expected }

            #expect(error(sut) == expected)
            #expect(store.stored.isEmpty)
        }
    }

    /// GP-09: after a denial, Start over opens a new loop at email entry.
    @Test func gp09_startOver_opensANewLoop() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        client.verifyOobResults = [.failure(Fix.terminal("access_denied", description: "authorization_rejected"))]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { error(sut) == .rejected }

        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        await sut.send(.restart)

        #expect(sut.step == .collectOTPIdentifier)
        #expect(sut.additionalStep == nil)
        #expect(client.calls.filter { $0 == .authorize(connection: "email") }.count == 2)
    }

    /// GP-12: the push can't be sent offline; the flow ends with No connection.
    @Test func gp12_offlineWhenSending_endsWithNoConnection() async {
        client.challengePushResults = [Fix.network]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { error(sut) == .network }

        #expect(error(sut) == .network)
        #expect(pushCalls == [.challengePush(index: 0)])
    }

    /// GP-13: a short outage while waiting is absorbed silently.
    @Test func gp13_shortOutageWhileWaiting_isAbsorbed() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        client.verifyOobResults = [.failure(Fix.network), .failure(Fix.network), .success(Credentials())]

        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { sut.step == .authenticated }

        #expect(sut.step == .authenticated)
    }

    /// GP-14: a long outage while waiting ends the flow with No connection. The push was sent once.
    @Test func gp14_longOutageWhileWaiting_endsTheFlow() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        client.verifyOobResults = Array(repeating: .failure(Fix.network), count: 4)
        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { error(sut) == .network }

        #expect(error(sut) == .network)
        #expect(pushCalls.filter { $0 == .challengePush(index: 0) }.count == 1)
    }

    // MARK: Navigation

    /// GP-15: Back while waiting stops checking and returns to email entry; a new email opens a new loop.
    @Test func gp15_backWhileWaiting_stopsAndRestarts() async {
        clock.suspends = true
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { pushModel(sut) != nil }

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)

        clock.suspends = false
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        await sut.send(.submitIdentifier(email))

        #expect(!pushCalls.contains(.verifyOob))
        #expect(sut.step == .collectOTPCode(identifier: email))
    }

    /// GP-16 / GP-17: with several devices Back leaves the additional step altogether; "Verify another way" is the
    /// way to the list.
    @Test func gp16_backWithSeveralDevices_leaves_andVerifyAnotherWayReturnsToTheList() async {
        clock.suspends = true
        client.challengePushResults = [Fix.needs([Fix.verifyOob()]), Fix.needs([Fix.verifyOob()])]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush, secondPush]))
        list(sut)?.select("push:0")
        await eventually { pushModel(sut) != nil }

        guard let model = pushModel(sut) else { Issue.record("not waiting"); return }
        #expect(model.canSwitch)
        model.switchFactor()
        #expect(list(sut) != nil)

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)
    }

    // MARK: Resend and polling

    /// GP-20: Resend shows only when the server still offers the push, and sends it again.
    @Test func gp20_resend_whenOffered() async {
        clock.suspends = true
        client.challengePushResults = [Fix.needs([Fix.verifyOob(), Fix.challengePush]), Fix.needs([Fix.verifyOob()])]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { pushModel(sut)?.canResend == true }

        pushModel(sut)?.resend()
        #expect(pushModel(sut)?.canResend == false, "the waiting screen stays, without a second resend")
        await eventually { pushCalls.filter { $0 == .challengePush(index: 0) }.count == 2 }
        await eventually { pushModel(sut)?.canResend == false }

        #expect(pushCalls.filter { $0 == .challengePush(index: 0) }.count == 2)
        #expect(pushModel(sut)?.canResend == false, "the server no longer offers it, so the button stays gone")
    }

    /// GP-22: the wait follows the server's interval, and grows after slow down.
    @Test func gp22_intervalsFollowTheServer() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob(pollInMs: 2_000)])]
        client.verifyOobResults = [
            .failure(Fix.needs([Fix.verifyOob(pollInMs: 3_000)], subReason: "authorization_pending")),
            .failure(Fix.needs([], subReason: "slow_down")),
            .success(Credentials())
        ]

        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { sut.step == .authenticated }

        #expect(clock.delays == [2_000, 3_000, 5_000])
    }

    // MARK: Credentials and server oddities

    /// GP-23: if the credentials can't be saved, approval ends on an error instead of signing in.
    @Test func gp23_keychainFailure_isAnError() async {
        store.error = NSError(domain: "keychain", code: -25308)
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { error(sut) == .credentialsNotSaved }

        #expect(error(sut) == .credentialsNotSaved)
        #expect(sut.step == .additionalStep)
        #expect(store.stored.isEmpty)
    }

    /// GP-29: the server answers the push without an approval step; that's an error, not a hang.
    @Test func gp29_pushWithoutApprovalStep_isAnError() async {
        client.challengePushResults = [Fix.needs([Fix.verifyTOTP])]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { error(sut) != nil }

        #expect(error(sut) == .unexpected(nil))
        #expect(!pushCalls.contains(.verifyOob))
    }

    /// GP-28: a double tap on a device sends one push.
    @Test func gp28_doubleTap_sendsOnePush() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush, secondPush]))

        guard let rows = list(sut) else { Issue.record("no list"); return }
        rows.select("push:1")
        rows.select("push:1")
        await eventually { sut.step == .authenticated }

        #expect(pushCalls.filter { $0 == .challengePush(index: 1) }.count == 1)
    }

    // MARK: Rounds

    /// After the approval the policy asks for another factor: the list returns with "One more step".
    @Test func anAdditionalFactor_showsTheListWithTheAdditionalHeader() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        client.verifyOobResults = [.failure(Fix.needs([Fix.challengePush, secondPush]))]

        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { list(sut) != nil }

        guard let rows = list(sut) else { Issue.record("no list"); return }
        #expect(rows.header == .challengeAdditional)
        #expect(rows.rows.count == 2)
        #expect(store.stored.isEmpty, "nothing is stored until the whole policy is met")
    }

    /// A policy that needs two factors: two rounds, a fresh push for each, and nothing stored until the second.
    @Test func aMultiStepSignIn_runsTwoRounds_thenStoresOnce() async {
        client.challengePushResults = [Fix.needs([Fix.verifyOob()]), Fix.needs([Fix.verifyOob()])]
        client.verifyOobResults = [.failure(Fix.needs([Fix.challengePush, secondPush])),
                                   .success(Credentials(accessToken: "final"))]

        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { list(sut)?.round == 2 }
        #expect(list(sut)?.header == .challengeAdditional)
        #expect(store.stored.isEmpty, "the first round only moved the sign-in along")

        list(sut)?.select("push:1")
        await eventually { sut.step == .authenticated }

        #expect(pushCalls == [.challengePush(index: 0), .verifyOob, .challengePush(index: 1), .verifyOob])
        #expect(store.stored.map(\.accessToken) == ["final"])
    }

    /// An approval that arrives after the user left is never stored (Cancel discards it).
    @Test func anApprovalAfterBack_isNeverStored() async {
        clock.suspends = true
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        client.verifyOobResults = [.success(Credentials(accessToken: "late"))]
        let sut = await signIn(afterTheCode: menu([Fix.challengePush]))
        await eventually { pushModel(sut) != nil }

        sut.goBack()
        clock.suspends = false
        await sut.send(.submitIdentifier(email))

        #expect(store.stored.isEmpty)
        #expect(sut.step != .authenticated)
    }
}
