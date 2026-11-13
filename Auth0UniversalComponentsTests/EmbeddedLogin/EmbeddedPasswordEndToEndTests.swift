@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// Sign-in with a username and password through the whole stack, composed the way `EmbeddedLoginView` composes it: the
/// real login interactor and coordinator, and the MFA adapter with Guardian push, against the scripted SDK client.
@Suite
@MainActor
struct EmbeddedPasswordEndToEndTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let username = "sarah.doe"
    private let password = "correct horse"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()

    /// Scripts discovery → username, answered by a request for the password, and opens the sign-in on the screen that
    /// asks for it.
    private func signIn(offering ways: [[String: Any]] = [Fix.identifyUsername]) async -> LoginFlowCoordinator {
        client.authorizeResults = [Fix.needs(ways)]
        client.identifyResults = [Fix.needs([Fix.verifyPassword])]
        let provider = EmbeddedMfaStep(clock: RecordingMfaClock(), bindings: [
            EmbeddedPushBinding(policy: PushPollingPolicy(resendCooldownSeconds: 0))
        ])
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "db")
        let sut = LoginFlowCoordinator(interactor: interactor, additionalStep: provider)
        await sut.send(.start)
        await sut.send(.submitIdentifier(.username(username)))
        return sut
    }

    @Test func theRightPassword_signsIn_andTheAppGetsTheCredentialsOnce() async {
        client.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]

        let sut = await signIn()
        #expect(sut.screen == .collectPassword(identifier: .username(username)))
        await sut.send(.submitPassword(password))

        #expect(sut.step == .authenticated)
        #expect(client.calls == [
            .authorize(connection: "db"), .identify(username, type: .username), .verifyPassword(password)
        ])
        #expect(store.delivered.map(\.accessToken) == ["pw"])
    }

    @Test func aWrongPassword_staysOnThePasswordScreen_thenTheRightOneSignsIn() async {
        client.verifyPasswordResults = [
            .failure(Fix.needs([Fix.verifyPassword], subReason: "invalid_identifier_or_password")),
            .success(Credentials(accessToken: "pw"))
        ]

        let sut = await signIn()
        await sut.send(.submitPassword("wrong"))
        #expect(sut.screen == .collectPassword(identifier: .username(username)))
        #expect(sut.inputError == .invalidPassword)
        #expect(store.delivered.isEmpty)

        await sut.send(.submitPassword(password))
        #expect(sut.step == .authenticated)
        #expect(store.delivered.map(\.accessToken) == ["pw"])
    }

    @Test func aBreachedPassword_endsOnAnErrorThatSaysWhy_andRetryAsksForThePasswordAgain() async {
        client.verifyPasswordResults = [.failure(Fix.terminal("access_denied", description: "password_leaked"))]

        let sut = await signIn()
        await sut.send(.submitPassword(password))
        guard case let .failed(message) = sut.step else { Issue.record("expected an error"); return }
        #expect(message.contains("data breach"))
        #expect(store.delivered.isEmpty)

        await sut.send(.retry)
        #expect(sut.screen == .collectPassword(identifier: .username(username)))
    }

    @Test func aTenantThatWantsMore_hasTheUserApproveOnTheirDeviceAfterThePassword() async {
        client.verifyPasswordResults = [.failure(Fix.needs([Fix.challengePush]))]
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        client.verifyOobResults = [.success(Credentials(accessToken: "push"))]

        let sut = await signIn()
        await sut.send(.submitPassword(password))
        #expect(sut.step == .additionalStep)
        #expect(store.delivered.isEmpty, "the password alone doesn't sign the user in")

        await eventually { sut.step == .authenticated }
        #expect(sut.step == .authenticated)
        #expect(client.calls.suffix(3) == [.verifyPassword(password), .challengePush(index: 0), .verifyOob])
        #expect(store.delivered.map(\.accessToken) == ["push"], "handed to the app once, after the last step")
    }

    @Test func backFromThePasswordScreen_returnsToTheUsername_whichCanBeChanged() async {
        let sut = await signIn()
        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier(.password))
        #expect(sut.enteredIdentifier == .username(username), "what was typed is kept")

        client.authorizeResults = [Fix.needs([Fix.identifyUsername])]
        client.identifyResults = [Fix.needs([Fix.verifyPassword])]
        await sut.send(.submitIdentifier(.username("someone.else")))
        #expect(sut.screen == .collectPassword(identifier: .username("someone.else")))
        #expect(client.calls.suffix(2) == [.authorize(connection: "db"), .identify("someone.else", type: .username)])
    }

    @Test func passwordBesideEmail_isChosenFromTheFirstScreen() async {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail, Fix.identifyUsername])]
        client.identifyResults = [Fix.needs([Fix.verifyPassword])]
        client.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "db")
        let sut = LoginFlowCoordinator(interactor: interactor)

        await sut.send(.start)
        #expect(sut.channels == [.email, .password])
        #expect(sut.step == .collectOTPIdentifier(.email))
        await sut.send(.chooseChannel(.password))
        await sut.send(.submitIdentifier(.username(username)))
        await sut.send(.submitPassword(password))

        #expect(sut.step == .authenticated)
        #expect(client.calls.first == .authorize(connection: "db"), "one loop, opened by discovery")
    }
}

/// A tenant that opens on an email or a number and decides what follows once it has one: a code, a password, or both.
/// Whichever it lists first leads, and the other is one tap away. `Username-Password-Authentication` answers
/// `identify:email`, then `challenge:email` with `verify:password`, so the code leads and the password is the
/// alternative; a tenant that lists the password first gets the password screen with the code as its alternative.
@Suite
@MainActor
struct ServerOrderEndToEndTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sudhanshu.vohra@okta.com"
    private let phone = "+14233530900"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()
    private let clock = TestClock()

    /// Opens the sign-in, submits `identifier`, and leaves it on whatever the server's answer leads to. `loops` is how
    /// many times the server is asked to open the sign-in (a password asked for after a code, or a code asked for
    /// after a wrong password, opens another).
    private func signIn(identifier: LoginIdentifier? = nil, afterIdentify next: [[String: Any]],
                        loops: Int = 1) async -> LoginFlowCoordinator {
        client.authorizeResults = Array(repeating: Fix.needs([Fix.identifyEmail, Fix.identifyPhone]), count: loops)
        client.identifyResults = Array(repeating: Fix.needs(next), count: loops)
        let provider = EmbeddedMfaStep(clock: RecordingMfaClock(), bindings: [
            EmbeddedPushBinding(policy: PushPollingPolicy(resendCooldownSeconds: 0))
        ])
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "db")
        let sut = LoginFlowCoordinator(interactor: interactor, additionalStep: provider, now: { clock.now })
        await sut.send(.start)
        await sut.send(.submitIdentifier(identifier ?? .email(email)))
        return sut
    }

    /// The tenant's own order: the code first.
    private var codeFirst: [[String: Any]] { [Fix.challengeEmail, Fix.verifyPassword] }
    private var passwordFirst: [[String: Any]] { [Fix.verifyPassword, Fix.challengeEmail] }

    // MARK: The code leads

    @Test func theTenantsOrder_sendsTheCodeAtOnce_andOffersThePasswordInstead() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        let sut = await signIn(afterIdentify: codeFirst)

        #expect(sut.channels == [.email, .phone], "no password option on the first screen: the tenant has none")
        #expect(sut.screen == .collectOTPCode(identifier: .email(email)))
        #expect(sut.canUsePassword)
        #expect(!sut.canSendCode)
        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1)
        ], "the email is submitted once, and the code goes out at once")
    }

    @Test func theCode_signsIn_andTheAppGetsTheCredentialsOnce() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "code"))]
        let sut = await signIn(afterIdentify: codeFirst)

        await sut.send(.submitOTP(code: "123456"))

        #expect(sut.step == .authenticated)
        #expect(store.delivered.map(\.accessToken) == ["code"])
    }

    @Test func aPasswordInstead_opensTheSignInAgain_andSignsIn() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]
        let sut = await signIn(afterIdentify: codeFirst, loops: 2)

        await sut.send(.usePasswordInstead)
        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(sut.canSendCode, "the code stays one tap away")
        #expect(!sut.canUsePassword)

        await sut.send(.submitPassword("correct horse"))
        #expect(sut.step == .authenticated)
        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1),
            .authorize(connection: "db"), .identify(email, type: .email), .verifyPassword("correct horse")
        ], "the code's loop may have ended, so the password is asked for on a fresh one")
        #expect(store.delivered.map(\.accessToken) == ["pw"])
    }

    @Test func backToTheCode_fromThePasswordThatWasAskedFor_sendsItAgainOnTheSameSignIn() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail]), Fix.needs([Fix.verifyEmail])]
        let sut = await signIn(afterIdentify: codeFirst, loops: 2)
        await sut.send(.usePasswordInstead)

        clock.waitOutTheCodeCooldown()
        await sut.send(.sendCodeInstead)

        #expect(sut.screen == .collectOTPCode(identifier: .email(email)))
        #expect(sut.canUsePassword, "and the password can be asked for again")
        #expect(client.calls.suffix(1) == [.challengeEmail(index: 1)], "the email is not submitted again")
    }

    @Test func resendingTheCode_staysOnTheCode_andKeepsThePasswordOffered() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail]), Fix.needs([Fix.verifyEmail])]
        let sut = await signIn(afterIdentify: codeFirst, loops: 2)

        await sut.resendOTP()

        #expect(sut.screen == .collectOTPCode(identifier: .email(email)))
        #expect(sut.canUsePassword)
        #expect(client.calls.filter { $0 == .challengeEmail(index: 1) }.count == 2)
    }

    @Test func aNumberOfferedATextThenAPassword_isTextedAtOnce() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        let sut = await signIn(identifier: .phone(phone), afterIdentify: [Fix.challengePhone(), Fix.verifyPassword])

        #expect(sut.screen == .collectOTPCode(identifier: .phone(phone), sentTo: "+1***99"))
        #expect(sut.canUsePassword)
        #expect(client.calls.last == .challengePhone(index: 0, deliveryMethod: .text))
    }

    @Test func aTenantWithNoPassword_goesStraightToTheCode_withNoPasswordToUse() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        let sut = await signIn(afterIdentify: [Fix.challengeEmail])

        #expect(sut.screen == .collectOTPCode(identifier: .email(email)))
        #expect(!sut.canUsePassword)
        #expect(!sut.canSendCode)
        let calls = client.calls
        await sut.send(.usePasswordInstead)
        #expect(sut.screen == .collectOTPCode(identifier: .email(email)), "there is nothing to switch to")
        #expect(client.calls == calls)
    }

    // MARK: The password leads

    @Test func aPasswordListedFirst_opensThePasswordScreen_withNoEmailSent() async {
        let sut = await signIn(afterIdentify: passwordFirst)

        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(sut.canSendCode)
        #expect(!sut.canUsePassword)
        #expect(client.calls == [.authorize(connection: "db"), .identify(email, type: .email)])
    }

    @Test func thePassword_signsIn_andTheAppGetsTheCredentialsOnce() async {
        client.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]
        let sut = await signIn(afterIdentify: passwordFirst)

        await sut.send(.submitPassword("correct horse"))

        #expect(sut.step == .authenticated)
        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .verifyPassword("correct horse")
        ], "no code was asked for")
        #expect(store.delivered.map(\.accessToken) == ["pw"])
    }

    @Test func aWrongPassword_staysOnTheScreen_thenTheRightOneSignsIn() async {
        client.verifyPasswordResults = [
            .failure(Fix.needs([Fix.verifyPassword], subReason: "invalid_identifier_or_password")),
            .success(Credentials(accessToken: "pw"))
        ]
        let sut = await signIn(afterIdentify: passwordFirst)

        await sut.send(.submitPassword("wrong"))
        #expect(sut.screen == .collectPassword(identifier: .email(email)))
        #expect(sut.inputError == .invalidPassword)

        await sut.send(.submitPassword("correct horse"))
        #expect(sut.step == .authenticated)
    }

    @Test func anEmailOfferedOnlyAPassword_signsInWithoutACodeToChoose() async {
        client.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]
        let sut = await signIn(afterIdentify: [Fix.verifyPassword])
        #expect(!sut.canSendCode)

        await sut.send(.submitPassword("correct horse"))
        #expect(sut.step == .authenticated)
    }

    @Test func aTenantThatWantsMore_hasThePasswordFollowedByTheUsersDevice() async {
        client.verifyPasswordResults = [.failure(Fix.needs([Fix.challengePush]))]
        client.challengePushResults = [Fix.needs([Fix.verifyOob()])]
        client.verifyOobResults = [.success(Credentials(accessToken: "push"))]
        let sut = await signIn(afterIdentify: passwordFirst)

        await sut.send(.submitPassword("correct horse"))
        #expect(sut.step == .additionalStep)
        await eventually { sut.step == .authenticated }

        #expect(sut.step == .authenticated)
        #expect(store.delivered.map(\.accessToken) == ["push"])
    }

    // MARK: A code instead

    @Test func aCodeInstead_isSentOnlyWhenAskedFor_andSignsIn() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "code"))]
        let sut = await signIn(afterIdentify: passwordFirst)

        await sut.send(.sendCodeInstead)
        #expect(sut.screen == .collectOTPCode(identifier: .email(email)))
        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1)
        ], "the email is submitted once")

        await sut.send(.submitOTP(code: "123456"))
        #expect(sut.step == .authenticated)
        #expect(store.delivered.map(\.accessToken) == ["code"])
    }

    @Test func aCodeInstead_afterAWrongPassword_startsTheSignInAgain() async {
        client.verifyPasswordResults = [
            .failure(Fix.needs([Fix.verifyPassword], subReason: "invalid_identifier_or_password"))
        ]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        let sut = await signIn(afterIdentify: passwordFirst, loops: 2)

        await sut.send(.submitPassword("wrong"))
        await sut.send(.sendCodeInstead)

        #expect(sut.screen == .collectOTPCode(identifier: .email(email)))
        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .verifyPassword("wrong"),
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1)
        ])
    }

    @Test func resendingACodeThatWasAskedFor_sendsAnother_ratherThanReturningToThePassword() async {
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail]), Fix.needs([Fix.verifyEmail])]
        let sut = await signIn(afterIdentify: passwordFirst, loops: 2)
        await sut.send(.sendCodeInstead)

        await sut.resendOTP()

        #expect(sut.screen == .collectOTPCode(identifier: .email(email)))
        #expect(sut.canUsePassword, "the password it came from is still one tap away")
        #expect(client.calls.filter { $0 == .challengeEmail(index: 1) }.count == 2)
    }

    @Test func aNumberOfferedAPasswordThenAText_opensThePasswordScreen_andCanBeTextedInstead() async {
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        let sut = await signIn(identifier: .phone(phone), afterIdentify: [Fix.verifyPassword, Fix.challengePhone()])

        #expect(sut.screen == .collectPassword(identifier: .phone(phone)))
        #expect(sut.canSendCode)

        await sut.send(.sendCodeInstead)
        #expect(sut.screen == .collectOTPCode(identifier: .phone(phone), sentTo: "+1***99"))
        #expect(client.calls.last == .challengePhone(index: 0, deliveryMethod: .text))
    }
}
