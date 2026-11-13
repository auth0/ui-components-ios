@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// Sign-in with a username and password through the Auth0 adapter, against the scripted SDK client.
@Suite
@MainActor
struct Auth0EmbeddedAuthPasswordTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let username = "sarah.doe"
    private let password = "correct horse"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()

    private func makeSUT() -> Auth0EmbeddedAuthInteractor {
        Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "db")
    }

    /// Scripts discovery → identify so `identify` lands on the password step.
    private func scriptUsernameLoop() {
        client.authorizeResults = [Fix.needs([Fix.identifyUsername])]
        client.identifyResults = [Fix.needs([Fix.verifyPassword])]
    }

    /// The interactor after the username was accepted and the password is asked for.
    private func atPasswordStep() async throws -> Auth0EmbeddedAuthInteractor {
        scriptUsernameLoop()
        let sut = makeSUT()
        _ = try await sut.discover()
        #expect(try await sut.identify(connection: "db", identifier: .username(username))
                == .passwordOffered(canSendCode: false))
        return sut
    }

    /// The text the user would see when the sign-in ends on a full-screen error.
    private func failureMessage(_ attempt: () async throws -> AuthProgress) async -> String? {
        do {
            _ = try await attempt()
            Issue.record("expected the sign-in to fail")
            return nil
        } catch let error as Auth0EmbeddedAuthError {
            return error.errorDescription
        } catch {
            Issue.record("unexpected error \(error)")
            return nil
        }
    }

    // MARK: Discovery and the username step

    @Test func discover_listsAUsernameAsTheWayToSignInWithAPassword() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyUsername])]
        #expect(try await makeSUT().discover() == [.password(connection: "db")])
    }

    @Test func discover_listsEveryWayTheServerOffers_inItsOrder() async throws {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail, Fix.identifyUsername, Fix.identifyPhone])]
        #expect(try await makeSUT().discover()
                == [.emailOTP(connection: "db"), .password(connection: "db"), .phoneOTP(connection: "db")])
    }

    @Test func discoverThenStartPassword_authorizesOnce_andIdentifiesTheUsername() async throws {
        _ = try await atPasswordStep()
        #expect(client.calls == [.authorize(connection: "db"), .identify(username, type: .username)])
    }

    @Test func identify_withoutDiscovery_opensTheLoopFirst() async throws {
        scriptUsernameLoop()
        _ = try await makeSUT().identify(connection: "db", identifier: .username(username))
        #expect(client.calls == [.authorize(connection: "db"), .identify(username, type: .username)])
    }

    @Test func secondStartPassword_reopensTheLoop() async throws {
        let sut = try await atPasswordStep()
        client.authorizeResults = [Fix.needs([Fix.identifyUsername])]
        client.identifyResults = [Fix.needs([Fix.verifyPassword])]
        _ = try await sut.identify(connection: "db", identifier: .username("someone.else"))
        #expect(client.calls.suffix(2) == [.authorize(connection: "db"), .identify("someone.else", type: .username)])
    }

    /// The server never says whether a username exists: with no password step offered, the user sees the same words as
    /// for a wrong password.
    @Test func identify_withoutAPasswordStep_isReportedAsAnInvalidPassword() async {
        client.authorizeResults = [Fix.needs([Fix.identifyUsername])]
        client.identifyResults = [Fix.needs([Fix.identifyUsername])]
        await #expect(throws: AuthFailure.invalidPassword) {
            try await makeSUT().identify(connection: "db", identifier: .username(username))
        }
    }

    @Test func identify_whenTheServerRefuses_endsOnAnError() async {
        client.authorizeResults = [Fix.needs([Fix.identifyUsername])]
        client.identifyResults = [Fix.terminal("access_denied", description: "authorization_rejected")]
        await #expect(throws: Auth0EmbeddedAuthError.self) {
            try await makeSUT().identify(connection: "db", identifier: .username(username))
        }
    }

    /// A username is never sent a code; asking for one is a mistake, not a request to forward.
    @Test func startOTP_forAUsername_isRefused_andSendsNothing() async {
        await #expect(throws: Auth0EmbeddedAuthError.self) {
            try await makeSUT().startOTP(connection: "db", identifier: .username(username))
        }
        #expect(client.calls.isEmpty)
    }

    // MARK: The password

    @Test func theRightPassword_signsIn_andHandsTheCredentialsToTheAppOnce() async throws {
        let sut = try await atPasswordStep()
        client.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]
        #expect(try await sut.verifyPassword(password) == .authenticated)
        #expect(client.calls.last == .verifyPassword(password))
        #expect(store.delivered.map(\.accessToken) == ["pw"])
    }

    @Test func aWrongPassword_isRejected_andAnotherCanBeTried() async throws {
        let sut = try await atPasswordStep()
        client.verifyPasswordResults = [
            .failure(Fix.needs([Fix.verifyPassword], subReason: "invalid_identifier_or_password")),
            .success(Credentials(accessToken: "pw"))
        ]
        await #expect(throws: AuthFailure.invalidPassword) { try await sut.verifyPassword("wrong") }
        #expect(store.delivered.isEmpty)
        #expect(try await sut.verifyPassword(password) == .authenticated)
        #expect(store.delivered.map(\.accessToken) == ["pw"])
    }

    @Test func whenTheServerWantsMore_thePasswordHandsTheSignInOn() async throws {
        let sut = try await atPasswordStep()
        client.verifyPasswordResults = [.failure(Fix.needs([Fix.challengePush]))]
        guard case let .additionalStepRequired(context) = try await sut.verifyPassword(password) else {
            Issue.record("expected an additional step")
            return
        }
        #expect(context.nextActions == [.challengePush(index: 0, name: "Sudhanshu's iPhone")])
        #expect(store.delivered.isEmpty, "nothing reaches the app before the sign-in is complete")
    }

    @Test func withNoFactorThatCanBeUsed_theAdditionalStepIsToldThereIsNone() async throws {
        let sut = try await atPasswordStep()
        client.verifyPasswordResults = [.failure(Fix.terminal("access_denied", description: "no_eligible_factors"))]
        guard case let .additionalStepRequired(context) = try await sut.verifyPassword(password) else {
            Issue.record("expected an additional step")
            return
        }
        #expect(context.nextActions.isEmpty)
    }

    @Test func tooManyAttempts_staysOnTheScreenWithItsOwnWords() async throws {
        let sut = try await atPasswordStep()
        client.verifyPasswordResults = [
            .failure(Fix.terminal("too_many_requests", description: "too_many_attempts", statusCode: 429))
        ]
        await #expect(throws: AuthFailure.tooManyAttempts) { try await sut.verifyPassword(password) }
    }

    @Test func aBreachedPassword_endsOnAnErrorThatSaysWhy() async throws {
        let sut = try await atPasswordStep()
        client.verifyPasswordResults = [.failure(Fix.terminal("access_denied", description: "password_leaked"))]
        let message = await failureMessage { try await sut.verifyPassword(password) }
        #expect(message?.contains("data breach") == true)
        #expect(message?.contains("password_leaked") == false, "the server's code is not shown")
    }

    @Test func anEndedSession_endsOnAnError() async throws {
        let sut = try await atPasswordStep()
        client.verifyPasswordResults = [.failure(Fix.terminal("invalid_grant", description: "expired"))]
        await #expect(throws: Auth0EmbeddedAuthError.self) { try await sut.verifyPassword(password) }
    }

    @Test func withoutAConnection_endsOnAnError() async throws {
        let sut = try await atPasswordStep()
        client.verifyPasswordResults = [.failure(Fix.network)]
        await #expect(throws: Auth0EmbeddedAuthError.self) { try await sut.verifyPassword(password) }
    }

    @Test func whenTheAppCannotTakeTheCredentials_theSignInEndsAsNotSaved() async throws {
        let sut = try await atPasswordStep()
        store.error = NSError(domain: "app", code: -25308)
        client.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]
        await #expect(throws: CredentialsNotSavedError.self) { try await sut.verifyPassword(password) }
        #expect(store.delivered.isEmpty)
    }

    // MARK: Words

    @Test func theWrongPasswordMessage_namesWhatWasTyped_butNeverWhichPartWasWrong() {
        for channel in [LoginChannel.password, .email, .phone] {
            let message = AuthFailure.invalidPassword.message(for: channel)
            #expect(message.hasPrefix("Incorrect ") && message.contains(" or password."), "either could be wrong")
        }
        #expect(AuthFailure.invalidPassword.message(for: .password)
                == "Incorrect username or password. Please try again.")
    }

    @Test func aUsername_hasNoCodeToFail() {
        for failure in [AuthFailure.invalidCode, .codeNotSent] {
            #expect(failure.message(for: .password) == "Something went wrong. Please try again.")
        }
    }
}
