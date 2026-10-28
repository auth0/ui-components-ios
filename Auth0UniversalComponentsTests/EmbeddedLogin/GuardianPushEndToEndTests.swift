@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// Guardian push through the whole Embedded Login stack: the real interactor, coordinator and push
/// controller against the scripted SDK client. Case IDs match docs/embedded-login-guardian-push-test-cases.md.
@Suite
@MainActor
struct GuardianPushEndToEndTests {

    private typealias F = EmbeddedAuthFixtures

    private let email = "sudhanshu.vohra@okta.com"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsStore()
    private let sleeper = RecordingSleeper()

    private let phone = GuardianPushDevice(index: 0, name: "Sudhanshu's iPhone")
    private let secondPhone = GuardianPushDevice(index: 1, name: "Sudhanshu's iPhone")
    private let secondPush: [String: Any] = ["action": "action:challenge:push:v1", "index": 1, "name": "Sudhanshu's iPhone"]

    /// Scripts discovery → email → challenge, then answers the email code with `secondFactor`.
    private func signIn(secondFactor: EmbeddedAuthError) async -> LoginFlowCoordinator {
        client.authorizeResults = [F.needs([F.identifyEmail])]
        client.identifyResults = [F.needs([F.challengeEmail])]
        client.challengeEmailResults = [F.needs([F.verifyEmail])]
        client.verifyOtpResults = [.failure(secondFactor)]
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsStore: store, connection: "email")
        let sut = LoginFlowCoordinator(interactor: interactor, pushSleep: sleeper.sleep)
        await sut.send(.start)
        await sut.send(.submitIdentifier(email))
        await sut.send(.submitOTP(code: "111111"))
        return sut
    }

    /// The tenant asks for a second factor and offers `menu`.
    private func menu(_ entries: [[String: Any]]) -> EmbeddedAuthError { F.needs(entries) }

    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<10_000 where !condition() { await Task.yield() }
    }

    private func pushState(_ sut: LoginFlowCoordinator) -> GuardianPushApprovalState? {
        sut.pushController?.state
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
        client.challengePushResults = [F.needs([F.verifyOob(pollInMs: 2_000)])]
        client.verifyOobResults = [.failure(F.needs([F.verifyOob(pollInMs: 2_000)], subReason: "authorization_pending")),
                                   .success(Credentials(accessToken: "push"))]

        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { sut.step == .authenticated }

        #expect(sut.step == .authenticated)
        #expect(pushCalls == [.challengePush(index: 0), .verifyOob, .verifyOob])
        #expect(store.stored.map(\.accessToken) == ["push"])
    }

    /// GP-02: several Guardian devices, so the user picks one and the push goes to that index.
    @Test func gp02_severalDevices_sendToThePickedOne() async {
        client.challengePushResults = [F.needs([F.verifyOob()])]

        let sut = await signIn(secondFactor: menu([F.challengePush, secondPush]))
        #expect(pushState(sut) == .choosingDevice([phone, secondPhone]))
        #expect(pushCalls.isEmpty)

        sut.pushController?.select(secondPhone)
        await eventually { sut.step == .authenticated }

        #expect(pushCalls.first == .challengePush(index: 1))
    }

    /// GP-03: the second-factor menu has no Guardian push, so the terminal state shows and nothing is sent.
    /// GP-03: the second-factor menu has no Guardian push (e.g. only an authenticator app or SMS), so the
    /// "verification method not available" screen shows and nothing is sent.
    @Test func gp03_noPushOnOffer_isTerminal() async {
        let sut = await signIn(secondFactor: menu([F.verifyTOTP, F.verifySMS]))

        #expect(sut.step == .secondFactorUnavailable)
        #expect(sut.pushController == nil)
        #expect(pushCalls.isEmpty)
        #expect(store.stored.isEmpty)
    }

    /// GP-06: MFA is required but the user has no eligible factor; same screen, not a retry on a dead session.
    @Test func gp06_noEligibleFactors_isTheSameTerminalState() async {
        let sut = await signIn(secondFactor: F.terminal("access_denied", description: "no_eligible_factors"))
        #expect(sut.step == .secondFactorUnavailable)
    }

    /// GP-04: no second factor needed, so the user is signed in without the push screen.
    @Test func gp04_noMFA_signsInDirectly() async {
        client.authorizeResults = [F.needs([F.identifyEmail])]
        client.identifyResults = [F.needs([F.challengeEmail])]
        client.challengeEmailResults = [F.needs([F.verifyEmail])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "email"))]
        let sut = LoginFlowCoordinator(interactor: Auth0EmbeddedAuthInteractor(client: client, credentialsStore: store,
                                                                               connection: "email"))
        await sut.send(.start)
        await sut.send(.submitIdentifier(email))
        await sut.send(.submitOTP(code: "111111"))

        #expect(sut.step == .authenticated)
        #expect(sut.pushController == nil)
    }

    /// GP-05: a wrong email code stays on the code screen; no push is involved.
    @Test func gp05_wrongEmailCode_staysInline() async {
        let sut = await signIn(secondFactor: F.needs([F.verifyEmail], subReason: "invalid_identifier_or_code"))

        #expect(sut.step == .collectOTPCode(identifier: email))
        #expect(sut.inputError == .invalidCode)
        #expect(pushCalls.isEmpty)
    }

    // MARK: Approval

    /// GP-09 / GP-10 / GP-11: terminal answers end the push with their own outcome.
    @Test func gp09_gp10_gp11_terminalAnswers() async {
        let cases: [(EmbeddedAuthError, GuardianPushFailure)] = [
            (F.terminal("access_denied", description: "authorization_rejected"), .denied),
            (F.terminal("access_denied", description: "challenge_expired"), .expired),
            (F.noActiveSession, .sessionEnded),
        ]
        for (error, failure) in cases {
            client.challengePushResults = [F.needs([F.verifyOob()])]
            client.verifyOobResults = [.failure(error)]

            let sut = await signIn(secondFactor: menu([F.challengePush]))
            await eventually { pushState(sut) == .failed(failure) }

            #expect(pushState(sut) == .failed(failure))
            #expect(store.stored.isEmpty)
        }
    }

    /// GP-09: after a denial, Sign in again opens a new loop at email entry.
    @Test func gp09_signInAgain_opensANewLoop() async {
        client.challengePushResults = [F.needs([F.verifyOob()])]
        client.verifyOobResults = [.failure(F.terminal("access_denied", description: "authorization_rejected"))]
        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { pushState(sut) == .failed(.denied) }

        client.authorizeResults = [F.needs([F.identifyEmail])]
        await sut.send(.restart)

        #expect(sut.step == .collectOTPIdentifier)
        #expect(sut.pushController == nil)
        #expect(client.calls.filter { $0 == .authorize(connection: "email") }.count == 2)
    }

    /// GP-12: the push can't be sent offline; Try again sends it again.
    @Test func gp12_offlineWhenSending_retrySendsAgain() async {
        client.challengePushResults = [F.network, F.needs([F.verifyOob()])]
        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { pushState(sut) == .failed(.network) }

        sut.pushController?.retry()
        await eventually { sut.step == .authenticated }

        #expect(pushCalls.filter { $0 == .challengePush(index: 0) }.count == 2)
    }

    /// GP-13: a short outage while waiting is absorbed silently.
    @Test func gp13_shortOutageWhileWaiting_isAbsorbed() async {
        client.challengePushResults = [F.needs([F.verifyOob()])]
        client.verifyOobResults = [.failure(F.network), .failure(F.network), .success(Credentials())]

        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { sut.step == .authenticated }

        #expect(sut.step == .authenticated)
    }

    /// GP-14: a long outage while waiting shows No connection; Try again resumes checking without a new push.
    @Test func gp14_longOutageWhileWaiting_retryResumesChecking() async {
        client.challengePushResults = [F.needs([F.verifyOob()])]
        client.verifyOobResults = Array(repeating: .failure(F.network), count: 4) + [.success(Credentials())]
        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { pushState(sut) == .failed(.network) }

        sut.pushController?.retry()
        await eventually { sut.step == .authenticated }

        #expect(pushCalls.filter { $0 == .challengePush(index: 0) }.count == 1)
    }

    // MARK: Navigation

    /// GP-15: Back while waiting stops checking and returns to email entry; a new email opens a new loop.
    @Test func gp15_backWhileWaiting_stopsAndRestarts() async {
        sleeper.suspends = true
        client.challengePushResults = [F.needs([F.verifyOob()])]
        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { pushState(sut) == .waiting(phone, canResend: false) }

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)

        sleeper.suspends = false
        client.authorizeResults = [F.needs([F.identifyEmail])]
        client.identifyResults = [F.needs([F.challengeEmail])]
        client.challengeEmailResults = [F.needs([F.verifyEmail])]
        await sut.send(.submitIdentifier(email))

        #expect(!pushCalls.contains(.verifyOob))
        #expect(sut.step == .collectOTPCode(identifier: email))
    }

    /// GP-16 / GP-17: with several devices, Back from waiting returns to the list, and Back again restarts.
    @Test func gp16_backWithSeveralDevices_returnsToTheList() async {
        sleeper.suspends = true
        client.challengePushResults = [F.needs([F.verifyOob()])]
        let sut = await signIn(secondFactor: menu([F.challengePush, secondPush]))
        sut.pushController?.select(phone)
        await eventually { pushState(sut) == .waiting(phone, canResend: false) }

        #expect(sut.goBack() == .movedBack)
        #expect(pushState(sut) == .choosingDevice([phone, secondPhone]))

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier)
    }

    // MARK: Resend and polling

    /// GP-20: Resend shows only when the server still offers the push, and sends it again.
    @Test func gp20_resend_whenOffered() async {
        sleeper.suspends = true
        client.challengePushResults = [F.needs([F.verifyOob(), F.challengePush]), F.needs([F.verifyOob()])]
        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { pushState(sut) == .waiting(phone, canResend: true) }

        sut.pushController?.resend()
        await eventually { pushState(sut) == .waiting(phone, canResend: false) }

        #expect(pushCalls.filter { $0 == .challengePush(index: 0) }.count == 2)
    }

    /// GP-22: the wait follows the server's interval, and grows after slow down.
    @Test func gp22_intervalsFollowTheServer() async {
        client.challengePushResults = [F.needs([F.verifyOob(pollInMs: 2_000)])]
        client.verifyOobResults = [.failure(F.needs([F.verifyOob(pollInMs: 3_000)], subReason: "authorization_pending")),
                                   .failure(F.needs([], subReason: "slow_down")),
                                   .success(Credentials())]

        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { sut.step == .authenticated }

        #expect(sleeper.delays == [2_000, 3_000, 5_000])
    }

    // MARK: Credentials and server oddities

    /// GP-23: if the credentials can't be saved, approval ends on an error instead of signing in.
    @Test func gp23_keychainFailure_isAnError() async {
        store.error = NSError(domain: "keychain", code: -25308)
        client.challengePushResults = [F.needs([F.verifyOob()])]
        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { if case .failed = pushState(sut) { return true } else { return false } }

        #expect(pushState(sut) == .failed(.other(message: CredentialsNotSavedError().errorDescription)))
        #expect(sut.step == .guardianPush)
    }

    /// GP-29: the server answers the push without an approval step; that's an error, not a hang.
    @Test func gp29_pushWithoutApprovalStep_isAnError() async {
        client.challengePushResults = [F.needs([F.verifyTOTP])]
        let sut = await signIn(secondFactor: menu([F.challengePush]))
        await eventually { if case .failed = pushState(sut) { return true } else { return false } }

        #expect(pushState(sut) == .failed(.other(message: nil)))
        #expect(!pushCalls.contains(.verifyOob))
    }

    /// GP-28: a double tap on a device sends one push.
    @Test func gp28_doubleTap_sendsOnePush() async {
        client.challengePushResults = [F.needs([F.verifyOob()])]
        let sut = await signIn(secondFactor: menu([F.challengePush, secondPush]))

        sut.pushController?.select(secondPhone)
        sut.pushController?.select(secondPhone)
        await eventually { sut.step == .authenticated }

        #expect(pushCalls.filter { $0 == .challengePush(index: 1) }.count == 1)
    }
}
