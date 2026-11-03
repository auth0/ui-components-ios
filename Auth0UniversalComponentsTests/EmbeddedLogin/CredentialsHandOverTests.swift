@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// The SDK keeps no credentials: a finished sign-in goes to the app's closure, once, and a refusal ends the sign-in.
@Suite
@MainActor
struct CredentialsHandOverTests {

    private typealias Fix = EmbeddedAuthFixtures

    private struct Refused: Error, Equatable {}

    private let email = "sudhanshu.vohra@okta.com"
    private let client = StubEmbeddedAuthClient()

    // MARK: The hand-over

    @Test func deliver_givesTheCredentialsToTheHandler() throws {
        var received: [String] = []
        let sut = CredentialsHandOver { received.append($0.accessToken) }

        try sut.deliver(credentials: Credentials(accessToken: "at"))

        #expect(received == ["at"])
    }

    /// The view swaps the closure on every render; a hand-over after that reaches the new one.
    @Test func aReplacedHandler_isTheOneThatIsCalled() throws {
        var first = 0
        var second = 0
        let sut = CredentialsHandOver { _ in first += 1 }
        sut.handler = { _ in second += 1 }

        try sut.deliver(credentials: Credentials())

        #expect(first == 0)
        #expect(second == 1)
    }

    @Test func aThrowingHandler_failsTheDelivery() {
        let sut = CredentialsHandOver { _ in throw Refused() }

        #expect(throws: Refused()) { try sut.deliver(credentials: Credentials()) }
    }

    // MARK: The email-code sign-in

    private func signIn(through handOver: CredentialsHandOver) async -> LoginFlowCoordinator {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.verifyOtpResults = [.success(Credentials(accessToken: "at"))]
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: handOver, connection: "email")
        let sut = LoginFlowCoordinator(interactor: interactor)
        await sut.send(.start)
        await sut.send(.submitIdentifier(email))
        await sut.send(.submitOTP(code: "111111"))
        return sut
    }

    @Test func anEmailCodeSignIn_handsTheCredentialsToTheApp_once() async {
        var received: [String] = []
        let sut = await signIn(through: CredentialsHandOver { received.append($0.accessToken) })

        #expect(received == ["at"])
        #expect(sut.step == .authenticated)
    }

    @Test func whenTheAppRefuses_theEmailCodeSignInDoesNotComplete() async {
        var calls = 0
        let sut = await signIn(through: CredentialsHandOver { _ in
            calls += 1
            throw Refused()
        })

        #expect(calls == 1)
        #expect(sut.step != .authenticated)
    }
}
