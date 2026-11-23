import Auth0
import Foundation
@testable import Auth0UniversalComponents

/// A sign-up over `SessionAwareEmbeddedAuthClient`, scripted with the menus of a sign-up that goes straight through.
/// Tests override what they need on `client.scripted`.
@MainActor
struct SignupHarness {
    typealias Fixtures = EmbeddedAuthFixtures

    final class Delivered {
        var credentials: [Credentials] = []
        var failsToSave = false
    }

    static let email = SignupIdentifierValue(kind: .email, value: "sarah.doe@example.com")
    static let phone = SignupIdentifierValue(kind: .phone, value: "+15551234567")
    /// The number as the server masks it in a challenge.
    static let maskedPhone = "+1XXXXXX4567"

    let client = SessionAwareEmbeddedAuthClient()
    let delivered = Delivered()
    let sut: SignupFlowCoordinator

    /// `kind` is what the connection signs up with: the script answers with that kind's menus.
    init(connection: String? = "db", kind: SignupIdentifierKind = .email) {
        let delivered = delivered
        let handOver = CredentialsHandOver { credentials in
            if delivered.failsToSave { throw CredentialsNotSavedError() }
            delivered.credentials.append(credentials)
        }
        let interactor = Auth0SignupInteractor(client: client, credentialsDelivery: handOver, connection: connection)
        sut = SignupFlowCoordinator(interactor: interactor)
        // Signup, then identify, challenge, verify, confirm.
        let script = client.scripted
        switch kind {
        case .email:
            script.authorizeResults = [Fixtures.needs([Fixtures.signup()])]
            script.signupResults = [Fixtures.needs([Fixtures.identifyEmail])]
            script.identifyResults = [Fixtures.needs([Fixtures.challengeEmail, Fixtures.identifyEmail])]
            script.challengeEmailResults = [Fixtures.needs([Fixtures.verifyEmail, Fixtures.challengeEmail,
                                                            Fixtures.identifyEmail])]
        case .phone:
            let challenge = Fixtures.challengePhone(masked: Self.maskedPhone)
            script.authorizeResults = [Fixtures.needs([Fixtures.signup(email: nil, phone: true)])]
            script.signupResults = [Fixtures.needs([Fixtures.identifyPhone])]
            script.identifyResults = [Fixtures.needs([challenge, Fixtures.identifyPhone])]
            script.challengePhoneResults = [Fixtures.needs([Fixtures.verifySMS, challenge, Fixtures.identifyPhone])]
        }
        script.verifyOtpResults = [.failure(Fixtures.needs([Fixtures.confirmSignup]))]
    }

    /// Opens the sign-up, enters the identifier and lands on the code screen.
    func onTheCodeScreen(_ identifier: SignupIdentifierValue = SignupHarness.email) async {
        await sut.send(.start)
        await sut.send(.submitIdentifier(identifier))
    }
}
