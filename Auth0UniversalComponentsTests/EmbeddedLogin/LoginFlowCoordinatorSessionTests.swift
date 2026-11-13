@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// The screens after the server ends the sign-in, through the real coordinator and interactor: whichever way forward
/// the screen offers must work.
@Suite
@MainActor
struct LoginFlowCoordinatorSessionTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sarah.doe@atko.email"
    private let client = SessionAwareEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()

    /// Opens the sign-in and submits the email, on a tenant that lists `offer` after it.
    private func signIn(offer: [[String: Any]], loops: Int = 3) async -> LoginFlowCoordinator {
        client.scripted.authorizeResults = Array(repeating: Fix.needs([Fix.identifyEmail]), count: loops)
        client.scripted.identifyResults = Array(repeating: Fix.needs(offer), count: loops)
        client.scripted.challengeEmailResults = Array(repeating: Fix.needs([Fix.verifyEmail]), count: loops)
        let interactor = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "db")
        let sut = LoginFlowCoordinator(interactor: interactor)
        await sut.send(.start)
        await sut.send(.submitIdentifier(.email(email)))
        return sut
    }

    private var passwordFirst: [[String: Any]] { [Fix.verifyPassword, Fix.challengeEmail] }
    private var codeFirst: [[String: Any]] { [Fix.challengeEmail, Fix.verifyPassword] }

    private func isOnPasswordScreen(_ sut: LoginFlowCoordinator) -> Bool {
        if case .collectPassword = sut.step { return true }
        return false
    }

    private func isOnCodeScreen(_ sut: LoginFlowCoordinator) -> Bool {
        if case .collectOTPCode = sut.step { return true }
        return false
    }

    // MARK: A rate-limited password

    @Test func aRateLimitedPassword_staysOnTheScreen_withTheMessage() async {
        client.scripted.verifyPasswordResults = [.failure(Fix.rateLimited)]
        let sut = await signIn(offer: passwordFirst)

        await sut.send(.submitPassword("first"))

        #expect(isOnPasswordScreen(sut))
        #expect(sut.inputError == .tooManyAttempts)
    }

    @Test func aRateLimitedPassword_leavesACodeToAskFor() async {
        client.scripted.verifyPasswordResults = [.failure(Fix.rateLimited)]
        let sut = await signIn(offer: passwordFirst)
        await sut.send(.submitPassword("first"))

        await sut.send(.sendCodeInstead)

        #expect(isOnCodeScreen(sut), "not a full-screen error about a missing session")
    }

    @Test func aRateLimitedPassword_leavesAnotherPasswordToTry() async {
        client.scripted.verifyPasswordResults = [.failure(Fix.rateLimited), .success(Credentials(accessToken: "pw"))]
        let sut = await signIn(offer: passwordFirst)
        await sut.send(.submitPassword("first"))

        await sut.send(.submitPassword("second"))

        #expect(sut.step == .authenticated)
        #expect(store.delivered.map(\.accessToken) == ["pw"])
    }

    // MARK: A breached password

    @Test func aBreachedPassword_thenTryAgain_thenANewPassword_signsIn() async {
        client.scripted.verifyPasswordResults = [
            .failure(Fix.terminal("access_denied", description: "password_leaked")),
            .success(Credentials(accessToken: "pw"))
        ]
        let sut = await signIn(offer: passwordFirst)
        await sut.send(.submitPassword("leaked"))
        guard case let .failed(message) = sut.step else { Issue.record("expected an error screen"); return }
        #expect(message.contains("data breach"))

        await sut.send(.retry)
        #expect(isOnPasswordScreen(sut))
        await sut.send(.submitPassword("new"))

        #expect(sut.step == .authenticated)
    }

    // MARK: Too many wrong codes

    @Test func tooManyWrongCodes_thenAnotherCheck_offersANewCode() async {
        client.scripted.verifyOtpResults = [
            .failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))
        ]
        let sut = await signIn(offer: [Fix.challengeEmail])
        await sut.send(.submitOTP(code: "111111"))
        #expect(sut.inputError == .tooManyAttempts)

        await sut.send(.submitOTP(code: "222222"))

        #expect(isOnCodeScreen(sut))
        #expect(sut.inputError == .codeNoLongerValid)
        #expect(sut.inputError?.needsNewCode == true, "so the screen offers Resend at once")
    }

    @Test func aNewCode_afterTheCodesRanOut_works() async {
        client.scripted.verifyOtpResults = [
            .failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts")),
            .success(Credentials(accessToken: "code"))
        ]
        let sut = await signIn(offer: [Fix.challengeEmail])
        await sut.send(.submitOTP(code: "111111"))

        await sut.resendOTP()
        await sut.send(.submitOTP(code: "222222"))

        #expect(sut.step == .authenticated)
    }

    @Test func thePasswordInstead_afterTooManyWrongCodes_works() async {
        client.scripted.verifyOtpResults = [
            .failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))
        ]
        client.scripted.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]
        let sut = await signIn(offer: codeFirst)
        await sut.send(.submitOTP(code: "111111"))

        await sut.send(.usePasswordInstead)
        await sut.send(.submitPassword("right"))

        #expect(sut.step == .authenticated)
    }
}
