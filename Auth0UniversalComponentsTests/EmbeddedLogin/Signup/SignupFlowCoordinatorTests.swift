import Auth0
import Foundation
import Testing
@testable import Auth0UniversalComponents

/// The sign-up from the coordinator down to the SDK's calls: the real interactor over `SessionAwareEmbeddedAuthClient`,
/// answering with the PRD's own menus. A retry against a session the server ended fails here as it would on a device.
@MainActor
@Suite struct SignupFlowCoordinatorTests {

    typealias Fixtures = EmbeddedAuthFixtures
    private let email = SignupHarness.email

    // MARK: Happy path (PRD Scenario 1)

    @Test func anEmailSignup_runsFromTheEntryToACreatedAccount() async {
        let harness = SignupHarness()
        let sut = harness.sut

        await sut.send(.start)
        #expect(sut.step == .collectIdentifier(.email))

        await sut.send(.submitIdentifier(email))
        #expect(sut.step == .collectCode(SignupCodeStep(identifier: email,
                                                        challenge: SignupChallenge(kind: .email, index: 1))))

        await sut.send(.submitCode("123456"))
        #expect(sut.step == .confirm)
        #expect(harness.delivered.credentials.isEmpty, "nothing is handed over before the account exists")

        await sut.send(.confirm)
        #expect(sut.step == .authenticated)
        #expect(harness.delivered.credentials.count == 1)
        #expect(harness.client.calls == [
            .authorize(connection: "db"), .signup, .identify("sarah.doe@example.com", type: .email),
            .challengeEmail(index: 1), .verifyOtp(code: "123456", type: .oob), .confirmSignup
        ])
    }

    @Test func authorize_advertisesOnlyWhatThereAreScreensFor() {
        #expect(Auth0SignupInteractor.capabilities
                == [.signup, .confirmSignup, .identifyEmail, .challengeEmail, .verifyOTP])
    }

    // MARK: A connection this flow can't finish

    @Test func aConnectionWithoutSignup_isUnavailable() async {
        let harness = SignupHarness()
        harness.client.scripted.authorizeResults = [Fixtures.needs([Fixtures.identifyEmail])]
        await harness.sut.send(.start)
        #expect(harness.sut.step == .unavailable)
        #expect(!harness.client.calls.contains(.signup))
    }

    @Test func aRequiredPhone_isUnavailable_untilThereAreScreensForIt() async {
        let harness = SignupHarness()
        let phone: [String: Any] = ["action": "action:signup:v1", "identifiers": ["phone_number": ["required": true]]]
        harness.client.scripted.authorizeResults = [Fixtures.needs([phone])]
        await harness.sut.send(.start)
        #expect(harness.sut.step == .unavailable)
    }

    @Test func aMissingConnection_failsWithAWayToTryAgain() async {
        let harness = SignupHarness(connection: nil)
        await harness.sut.send(.start)
        guard case .failed(_, canRetry: true) = harness.sut.step else { Issue.record("\(harness.sut.step)"); return }
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

    // MARK: Invalid email (PRD Scenario 10)

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

    // MARK: An email that already has an account (PRD Scenario 26)

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
