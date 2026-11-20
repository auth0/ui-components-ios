import Auth0
import Foundation
@testable import Auth0UniversalComponents

/// A sign-up over `SessionAwareEmbeddedAuthClient`, scripted with the PRD's Scenario 1 menus. Tests override what they
/// need on `client.scripted`.
@MainActor
struct SignupHarness {
    typealias Fixtures = EmbeddedAuthFixtures

    final class Delivered {
        var credentials: [Credentials] = []
        var failsToSave = false
    }

    static let email = SignupIdentifierValue(kind: .email, value: "sarah.doe@example.com")

    let client = SessionAwareEmbeddedAuthClient()
    let delivered = Delivered()
    let sut: SignupFlowCoordinator

    init(connection: String? = "db") {
        let delivered = delivered
        let handOver = CredentialsHandOver { credentials in
            if delivered.failsToSave { throw CredentialsNotSavedError() }
            delivered.credentials.append(credentials)
        }
        let interactor = Auth0SignupInteractor(client: client, credentialsDelivery: handOver, connection: connection)
        sut = SignupFlowCoordinator(interactor: interactor)
        // PRD Scenario 1: signup, then identify, challenge, verify, confirm.
        let script = client.scripted
        script.authorizeResults = [Fixtures.needs([Fixtures.signup()])]
        script.signupResults = [Fixtures.needs([Fixtures.identifyEmail])]
        script.identifyResults = [Fixtures.needs([Fixtures.challengeEmail, Fixtures.identifyEmail])]
        script.challengeEmailResults = [Fixtures.needs([Fixtures.verifyEmail, Fixtures.challengeEmail,
                                                        Fixtures.identifyEmail])]
        script.verifyOtpResults = [.failure(Fixtures.needs([Fixtures.confirmSignup]))]
    }

    /// Opens the sign-up, enters the email and lands on the code screen.
    func onTheCodeScreen() async {
        await sut.send(.start)
        await sut.send(.submitIdentifier(Self.email))
    }
}
