@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// What the interactor does once the server has ended the sign-in. The SDK ends it on every failure except a
/// continuation or a network error, and fails every later call with `no_active_session`, so each test runs against a
/// client that behaves that way.
@Suite
@MainActor
struct Auth0EmbeddedAuthSessionTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sarah.doe@atko.email"
    private let client = SessionAwareEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()

    private func makeSUT() -> Auth0EmbeddedAuthInteractor {
        Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "db")
    }

    /// A tenant that lists the password first. `loops` is how many times the sign-in may be opened.
    private func script(loops: Int = 3) {
        client.scripted.authorizeResults = Array(repeating: Fix.needs([Fix.identifyEmail]), count: loops)
        client.scripted.identifyResults = Array(repeating: Fix.needs([Fix.verifyPassword, Fix.challengeEmail]),
                                                count: loops)
    }

    /// The password is asked for, tried once, and the server answers `error` and ends the sign-in.
    private func endedByPassword(_ error: EmbeddedAuthError) async throws -> Auth0EmbeddedAuthInteractor {
        script()
        client.scripted.verifyPasswordResults = [.failure(error), .success(Credentials(accessToken: "pw"))]
        let sut = makeSUT()
        _ = try await sut.identify(connection: "db", identifier: .email(email))
        await #expect(throws: (any Error).self) { try await sut.verifyPassword("first") }
        #expect(!client.hasSession, "the server ended it")
        return sut
    }

    // MARK: A password after the sign-in ended

    @Test func aRateLimitedPassword_isTriedAgainOnANewSignIn() async throws {
        let sut = try await endedByPassword(Fix.rateLimited)

        #expect(try await sut.verifyPassword("second") == .authenticated)

        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .verifyPassword("first"),
            .authorize(connection: "db"), .identify(email, type: .email), .verifyPassword("second")
        ])
        #expect(store.delivered.map(\.accessToken) == ["pw"])
    }

    @Test func aBreachedPassword_isTriedAgainOnANewSignIn() async throws {
        let sut = try await endedByPassword(Fix.terminal("access_denied", description: "password_leaked"))
        #expect(try await sut.verifyPassword("second") == .authenticated)
    }

    @Test func anExpiredSession_isReopenedForThePassword() async throws {
        let sut = try await endedByPassword(Fix.terminal("invalid_grant", description: "expired"))
        #expect(try await sut.verifyPassword("second") == .authenticated)
    }

    @Test func aRateLimitedPassword_showsTheInlineMessage() async throws {
        script()
        client.scripted.verifyPasswordResults = [.failure(Fix.rateLimited)]
        let sut = makeSUT()
        _ = try await sut.identify(connection: "db", identifier: .email(email))
        await #expect(throws: AuthFailure.tooManyAttempts) { try await sut.verifyPassword("first") }
    }

    // MARK: A re-open that doesn't get through

    @Test func aReopenThatTheServerRefuses_isTriedAgainOnTheNextPassword() async throws {
        script()
        // The sign-in opens, the password is limited, the re-open is limited at identify, the next re-open works.
        client.scripted.identifyResults = [Fix.needs([Fix.verifyPassword, Fix.challengeEmail]), Fix.rateLimited,
                                           Fix.needs([Fix.verifyPassword, Fix.challengeEmail])]
        client.scripted.verifyPasswordResults = [.failure(Fix.rateLimited), .success(Credentials(accessToken: "pw"))]
        let sut = makeSUT()
        _ = try await sut.identify(connection: "db", identifier: .email(email))
        _ = try? await sut.verifyPassword("first")

        await #expect(throws: AuthFailure.tooManyAttempts) { try await sut.verifyPassword("second") }
        #expect(try await sut.verifyPassword("third") == .authenticated)

        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .verifyPassword("first"),
            .authorize(connection: "db"), .identify(email, type: .email),
            .authorize(connection: "db"), .identify(email, type: .email), .verifyPassword("third")
        ], "the password is never sent on a sign-in the server hasn't identified")
    }

    @Test func aReopenThatLosesTheConnection_identifiesAgainBeforeThePassword() async throws {
        script()
        client.scripted.identifyResults = [Fix.needs([Fix.verifyPassword, Fix.challengeEmail]), Fix.network,
                                           Fix.needs([Fix.verifyPassword, Fix.challengeEmail])]
        client.scripted.verifyPasswordResults = [.failure(Fix.rateLimited), .success(Credentials(accessToken: "pw"))]
        let sut = makeSUT()
        _ = try await sut.identify(connection: "db", identifier: .email(email))
        _ = try? await sut.verifyPassword("first")

        await #expect(throws: (any Error).self) { try await sut.verifyPassword("second") }
        #expect(try await sut.verifyPassword("third") == .authenticated)

        #expect(client.calls.suffix(3) == [
            .identify(email, type: .email), .identify(email, type: .email), .verifyPassword("third")
        ], "the sign-in lived, so it is identified again rather than opened again")
    }

    // MARK: A code after the sign-in ended

    @Test func aCode_afterAPasswordRateLimit_startsFromTheTop() async throws {
        let sut = try await endedByPassword(Fix.rateLimited)
        client.scripted.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]

        try await sut.startOTP(connection: "db", identifier: .email(email))

        #expect(client.calls.suffix(3) == [
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1)
        ], "not the stale offer on a dead sign-in")
    }

    @Test func tooManyWrongCodes_endTheSignIn_andAnotherCheckSaysTheCodeIsNoLongerValid() async throws {
        client.scripted.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.scripted.identifyResults = [Fix.needs([Fix.challengeEmail])]
        client.scripted.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        client.scripted.verifyOtpResults = [
            .failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts"))
        ]
        let sut = makeSUT()
        try await sut.startOTP(connection: "db", identifier: .email(email))

        await #expect(throws: AuthFailure.tooManyAttempts) { try await sut.verifyOTP(code: "111111") }
        let calls = client.calls.count
        await #expect(throws: AuthFailure.codeNoLongerValid) { try await sut.verifyOTP(code: "222222") }
        #expect(client.calls.count == calls, "nothing is sent on a sign-in that is over")
    }

    @Test func aNewCode_afterTheCodesRanOut_opensANewSignIn() async throws {
        client.scripted.authorizeResults = Array(repeating: Fix.needs([Fix.identifyEmail]), count: 2)
        client.scripted.identifyResults = Array(repeating: Fix.needs([Fix.challengeEmail]), count: 2)
        client.scripted.challengeEmailResults = Array(repeating: Fix.needs([Fix.verifyEmail]), count: 2)
        client.scripted.verifyOtpResults = [
            .failure(Fix.terminal("access_denied", description: "too_many_wrong_otp_attempts")),
            .success(Credentials(accessToken: "code"))
        ]
        let sut = makeSUT()
        try await sut.startOTP(connection: "db", identifier: .email(email))
        _ = try? await sut.verifyOTP(code: "111111")

        try await sut.startOTP(connection: "db", identifier: .email(email))

        #expect(try await sut.verifyOTP(code: "222222") == .authenticated)
    }

    // MARK: What leaves the sign-in alone

    @Test func aWrongPassword_keepsTheSignIn_soAnotherIsNotAReopen() async throws {
        script()
        client.scripted.verifyPasswordResults = [
            .failure(Fix.needs([Fix.verifyPassword], subReason: "invalid_identifier_or_password")),
            .success(Credentials(accessToken: "pw"))
        ]
        let sut = makeSUT()
        _ = try await sut.identify(connection: "db", identifier: .email(email))

        await #expect(throws: AuthFailure.invalidPassword) { try await sut.verifyPassword("wrong") }
        #expect(try await sut.verifyPassword("right") == .authenticated)

        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email),
            .verifyPassword("wrong"), .verifyPassword("right")
        ])
    }

    @Test func aNetworkDrop_keepsTheSignIn_soAnotherTryIsNotAReopen() async throws {
        script()
        client.scripted.verifyPasswordResults = [.failure(Fix.network), .success(Credentials(accessToken: "pw"))]
        let sut = makeSUT()
        _ = try await sut.identify(connection: "db", identifier: .email(email))

        await #expect(throws: (any Error).self) { try await sut.verifyPassword("first") }
        #expect(try await sut.verifyPassword("second") == .authenticated)

        #expect(client.calls.filter { $0 == .authorize(connection: "db") }.count == 1)
    }

    @Test func aCodeSentAfterAWrongPassword_startsFromTheTop() async throws {
        script()
        client.scripted.verifyPasswordResults = [
            .failure(Fix.needs([Fix.verifyPassword], subReason: "invalid_identifier_or_password"))
        ]
        client.scripted.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        let sut = makeSUT()
        _ = try await sut.identify(connection: "db", identifier: .email(email))
        _ = try? await sut.verifyPassword("wrong")

        try await sut.startOTP(connection: "db", identifier: .email(email))

        #expect(client.calls.suffix(3) == [
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1)
        ], "the server offers only the password now")
    }

    // MARK: Words

    @Test func theSessionsEnd_isNeverShownInTheSDKsWords() {
        #expect(Fix.noActiveSession.displayMessage == "Your sign-in timed out. Please try again.")
        #expect(Fix.terminal("invalid_grant", description: "expired").displayMessage
                == "Your sign-in timed out. Please try again.")
    }

    @Test func aMissingNextStep_hasWordsOfItsOwn() {
        let noSteps = Fix.terminal("access_denied", description: "no_next_steps")
        #expect(noSteps.displayMessage != "no_next_steps")
        #expect(noSteps.displayMessage?.isEmpty == false)
    }
}
