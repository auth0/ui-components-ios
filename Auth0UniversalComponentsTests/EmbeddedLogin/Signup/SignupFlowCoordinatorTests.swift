import Auth0
import Foundation
import Testing
@testable import Auth0UniversalComponents

/// The sign-up from the coordinator down to the SDK's calls: the real interactor over `SessionAwareEmbeddedAuthClient`,
/// answering with the menus the server sends. A retry against a session the server ended fails here as it would on a
/// device.
@MainActor
@Suite struct SignupFlowCoordinatorTests {

    typealias Fixtures = EmbeddedAuthFixtures
    private let email = SignupHarness.email

    // MARK: Happy path 

    @Test func anEmailSignup_runsFromTheEntryToACreatedAccount() async {
        let harness = SignupHarness()
        let sut = harness.sut

        await sut.send(.start)
        #expect(sut.step == .collectIdentifier(.email))

        await sut.send(.submitIdentifier(email))
        #expect(sut.step == .collectCode(SignupCodeStep(identifier: email,
                                                        challenge: SignupChallenge(index: 1),
                                                        delivery: .email)))

        await sut.send(.submitCode("123456"))
        #expect(sut.step == .confirm)
        #expect(harness.delivered.credentials.isEmpty, "nothing is handed over before the account exists")

        await sut.send(.confirm)
        #expect(sut.step == .created)
        #expect(harness.delivered.credentials.isEmpty, "the app waits for Continue on the created screen")

        await sut.send(.finish)
        #expect(sut.step == .authenticated)
        #expect(harness.delivered.credentials.count == 1)
        #expect(harness.client.calls == [
            .authorize(connection: "db"), .signup, .identify("sarah.doe@example.com", type: .email),
            .challengeEmail(index: 1), .verifyOtp(code: "123456", type: .oob), .confirmSignup
        ])
    }

    @Test func authorize_advertisesOnlyWhatThereAreScreensFor() {
        #expect(Auth0SignupInteractor.capabilities
                == [.signup, .confirmSignup, .identifyEmail, .challengeEmail, .verifyOTP, .identifyPhone,
                    .challengePhone])
    }

    // MARK: A connection this flow can't finish

    @Test func aConnectionWithoutSignup_isUnavailable() async {
        let harness = SignupHarness()
        harness.client.scripted.authorizeResults = [Fixtures.needs([Fixtures.identifyEmail])]
        await harness.sut.send(.start)
        #expect(harness.sut.step == .unavailable)
        #expect(!harness.client.calls.contains(.signup))
    }

    @Test func twoRequiredIdentifiers_areUnavailable_untilThereAreScreensForBoth() async {
        let harness = SignupHarness()
        harness.client.scripted.authorizeResults = [Fixtures.needs([Fixtures.signup(email: true, phone: true)])]
        await harness.sut.send(.start)
        #expect(harness.sut.step == .unavailable)
    }

    /// Opening again would give the same answer, so there is no "Try again".
    @Test func aMissingConnection_failsWithoutAWayToTryAgain() async {
        let harness = SignupHarness(connection: nil)
        await harness.sut.send(.start)
        guard case .failed(_, canRetry: false) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
    }

    @Test func aServerWordInAnError_isNeverShown() async {
        let harness = SignupHarness()
        harness.client.scripted.identifyResults = [
            Fixtures.terminal("invalid_request", description: "Connection xyz-secret-name is disabled",
                              statusCode: 400)]
        await harness.sut.send(.start)

        await harness.sut.send(.submitIdentifier(email))

        guard case let .failed(message, _) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(!message.contains("xyz-secret-name"))
    }

    // MARK: Invalid email 

    @Test func anInvalidEmail_staysOnTheEntry_withTheMessage_andTheNextTryWorks() async {
        let harness = SignupHarness()
        let script = harness.client.scripted
        script.identifyResults = [Fixtures.needs([Fixtures.identifyEmail], subReason: "invalid_email"),
                                  Fixtures.needs([Fixtures.challengeEmail, Fixtures.identifyEmail])]
        await harness.sut.send(.start)

        await harness.sut.send(.submitIdentifier(email))
        #expect(harness.sut.step == .collectIdentifier(.email))
        #expect(harness.sut.inputError == .invalidEmail)
        #expect(harness.sut.entered == email, "what was typed comes back")

        await harness.sut.send(.submitIdentifier(email))
        #expect(harness.sut.inputError == nil)
        guard case .collectCode = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
    }

    // MARK: Edit and Back

    @Test func back_fromTheCodeScreen_returnsToTheEntry_withTheEmailKept() async {
        let harness = SignupHarness()
        await harness.onTheCodeScreen()

        #expect(harness.sut.goBack() == .movedBack)

        #expect(harness.sut.step == .collectIdentifier(.email))
        #expect(harness.sut.entered == email)
    }

    @Test func back_fromTheEntry_leavesTheFlow() async {
        let harness = SignupHarness()
        await harness.sut.send(.start)
        #expect(harness.sut.goBack() == .exitFlow)
    }

    @Test func editingTheEmail_asksTheServerAgain_withTheNewOne() async {
        let harness = SignupHarness()
        await harness.onTheCodeScreen()
        harness.sut.goBack()
        harness.client.scripted.identifyResults = [Fixtures.needs([Fixtures.challengeEmail, Fixtures.identifyEmail])]
        harness.client.scripted.challengeEmailResults = [
            Fixtures.needs([Fixtures.verifyEmail, Fixtures.challengeEmail])]

        await harness.sut.send(.submitIdentifier(SignupIdentifierValue(kind: .email, value: "sarah@example.com")))

        #expect(harness.client.calls.contains(.identify("sarah@example.com", type: .email)))
        guard case let .collectCode(code) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(code.identifier.value == "sarah@example.com")
    }

    // MARK: An email that already has an account

    @Test func anExistingAccount_isSignedIn_withoutConfirming() async {
        let harness = SignupHarness()
        harness.client.scripted.verifyOtpResults = [.success(Credentials())]
        await harness.onTheCodeScreen()

        await harness.sut.send(.submitCode("123456"))

        #expect(harness.sut.step == .authenticated)
        #expect(harness.delivered.credentials.count == 1)
        #expect(!harness.client.calls.contains(.confirmSignup))
    }
}

/// The screen that says the account is created, and the app being given the credentials from it.
@MainActor
@Suite struct SignupCreatedTests {

    private func created() async -> SignupHarness {
        let harness = SignupHarness()
        await harness.onTheCodeScreen()
        await harness.sut.send(.submitCode("123456"))
        await harness.sut.send(.confirm)
        return harness
    }

    @Test func theCredentialsAreHandedOverOnce_whenTheUserContinues() async {
        let harness = await created()
        #expect(harness.sut.step == .created)
        #expect(harness.delivered.credentials.isEmpty)

        await harness.sut.send(.finish)
        await harness.sut.send(.finish)

        #expect(harness.sut.step == .authenticated)
        #expect(harness.delivered.credentials.count == 1)
    }

    @Test func thereIsNoGoingBack_fromTheCreatedScreen() async {
        let harness = await created()

        #expect(harness.sut.goBack() == .ignored)

        #expect(harness.sut.step == .created)
    }

    @Test func continuing_beforeTheAccountExists_doesNothing() async {
        let harness = SignupHarness()
        await harness.onTheCodeScreen()

        await harness.sut.send(.finish)

        guard case .collectCode = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
        #expect(harness.delivered.credentials.isEmpty)
    }
}
