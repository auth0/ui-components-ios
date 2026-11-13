@testable import Auth0UniversalComponents
import Auth0
import Foundation
import Testing

/// What the server offers once it has the email or number, and a code that follows without submitting it again.
@Suite
@MainActor
struct Auth0EmbeddedAuthIdentifyTests {

    private typealias Fix = EmbeddedAuthFixtures

    private let email = "sarah.doe@atko.email"
    private let phone = "+14233530900"
    private let client = StubEmbeddedAuthClient()
    private let store = StubCredentialsDelivery()

    private func makeSUT() -> Auth0EmbeddedAuthInteractor {
        Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "db")
    }

    /// The tenant opens on an email or a number, and says what follows once it has one.
    private func script(afterIdentify next: [[String: Any]], loops: Int = 1) {
        client.authorizeResults = Array(repeating: Fix.needs([Fix.identifyEmail, Fix.identifyPhone]), count: loops)
        client.identifyResults = Array(repeating: Fix.needs(next), count: loops)
    }

    // MARK: What is offered

    /// The order is the server's: whichever it lists first leads, and the other is the alternative.
    @Test func anEmailOfferedACodeThenAPassword_leadsWithTheCode_andSendsNothingYet() async throws {
        script(afterIdentify: [Fix.challengeEmail, Fix.verifyPassword])

        let outcome = try await makeSUT().identify(connection: "db", identifier: .email(email))

        #expect(outcome == .codeOffered(canUsePassword: true))
        #expect(client.calls == [.authorize(connection: "db"), .identify(email, type: .email)],
                "identify sends nothing: the code goes out when it is asked for")
    }

    @Test func anEmailOfferedAPasswordThenACode_leadsWithThePassword() async throws {
        script(afterIdentify: [Fix.verifyPassword, Fix.challengeEmail])
        #expect(try await makeSUT().identify(connection: "db", identifier: .email(email))
                == .passwordOffered(canSendCode: true))
    }

    @Test func otherThingsInTheMenu_doNotChangeWhoLeads() async throws {
        script(afterIdentify: [Fix.challengePush, Fix.verifyPassword, Fix.verifyTOTP, Fix.challengeEmail])
        #expect(try await makeSUT().identify(connection: "db", identifier: .email(email))
                == .passwordOffered(canSendCode: true), "the password is listed before the email")
    }

    // MARK: A code the server has already sent

    @Test func anEmailTheServerHasAlreadySentACodeTo_leadsWithTheCode_andSendsNoSecondOne() async throws {
        script(afterIdentify: [Fix.verifyEmail, Fix.verifyPassword])
        let sut = makeSUT()

        let outcome = try await sut.identify(connection: "db", identifier: .email(email))
        try await sut.startOTP(connection: "db", identifier: .email(email))

        #expect(outcome == .codeOffered(canUsePassword: true))
        #expect(client.calls == [.authorize(connection: "db"), .identify(email, type: .email)],
                "nothing is asked for: the code is on its way")
    }

    @Test func aNumberTheServerHasAlreadyTextedACodeTo_leadsWithTheCode() async throws {
        script(afterIdentify: [Fix.verifySMS, Fix.verifyPassword])
        #expect(try await makeSUT().identify(connection: "db", identifier: .phone(phone))
                == .codeOffered(canUsePassword: true))
    }

    @Test func aCodeThatWillBeCalledIn_isNotACodeThisFlowOffers() async throws {
        script(afterIdentify: [Fix.verifyVoice, Fix.verifyPassword])
        #expect(try await makeSUT().identify(connection: "db", identifier: .phone(phone))
                == .passwordOffered(canSendCode: false))
    }

    @Test func anEmailOfferedOnlyAPassword_cannotBeSentACode() async throws {
        script(afterIdentify: [Fix.verifyPassword])
        #expect(try await makeSUT().identify(connection: "db", identifier: .email(email))
                == .passwordOffered(canSendCode: false))
    }

    @Test func anEmailOfferedOnlyACode_isNotOfferedAPassword() async throws {
        script(afterIdentify: [Fix.challengeEmail])
        #expect(try await makeSUT().identify(connection: "db", identifier: .email(email))
                == .codeOffered(canUsePassword: false))
    }

    @Test func aNumberOfferedATextThenAPassword_leadsWithTheText() async throws {
        script(afterIdentify: [Fix.challengePhone(), Fix.verifyPassword])
        #expect(try await makeSUT().identify(connection: "db", identifier: .phone(phone))
                == .codeOffered(canUsePassword: true))
        #expect(client.calls == [.authorize(connection: "db"), .identify(phone, type: .phone)])
    }

    @Test func aNumberOfferedAPasswordThenAText_leadsWithThePassword() async throws {
        script(afterIdentify: [Fix.verifyPassword, Fix.challengePhone()])
        #expect(try await makeSUT().identify(connection: "db", identifier: .phone(phone))
                == .passwordOffered(canSendCode: true))
    }

    // MARK: The app's preference

    private func outcome(_ order: [[String: Any]], preferring preference: EmbeddedLoginPreference) async throws
        -> IdentifierOutcome {
        script(afterIdentify: order)
        let sut = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: store, connection: "db",
                                              preference: preference)
        return try await sut.identify(connection: "db", identifier: .email(email))
    }

    @Test func aCodePreference_leadsWithTheCode_whateverTheServersOrder() async throws {
        #expect(try await outcome([Fix.challengeEmail, Fix.verifyPassword], preferring: .code)
                == .codeOffered(canUsePassword: true))
        #expect(try await outcome([Fix.verifyPassword, Fix.challengeEmail], preferring: .code)
                == .codeOffered(canUsePassword: true))
    }

    @Test func aPasswordPreference_leadsWithThePassword_whateverTheServersOrder() async throws {
        #expect(try await outcome([Fix.challengeEmail, Fix.verifyPassword], preferring: .password)
                == .passwordOffered(canSendCode: true))
        #expect(try await outcome([Fix.verifyPassword, Fix.challengeEmail], preferring: .password)
                == .passwordOffered(canSendCode: true))
    }

    @Test func theServerPreference_followsTheServersOrder() async throws {
        #expect(try await outcome([Fix.challengeEmail, Fix.verifyPassword], preferring: .server)
                == .codeOffered(canUsePassword: true))
        #expect(try await outcome([Fix.verifyPassword, Fix.challengeEmail], preferring: .server)
                == .passwordOffered(canSendCode: true))
    }

    @Test func aPreference_cannotOfferWhatTheServerDoesNot() async throws {
        #expect(try await outcome([Fix.challengeEmail], preferring: .password) == .codeOffered(canUsePassword: false))
        #expect(try await outcome([Fix.verifyPassword], preferring: .code) == .passwordOffered(canSendCode: false))
    }

    @Test func aNumberThatOnlyTakesCalls_cannotBeSentACodeHere() async throws {
        script(afterIdentify: [Fix.challengePhone(methods: ["voice"]), Fix.verifyPassword])
        #expect(try await makeSUT().identify(connection: "db", identifier: .phone(phone))
                == .passwordOffered(canSendCode: false), "this flow doesn't offer voice calls")
    }

    @Test func aNumberOfferedOnlyATextCode_isNotOfferedAPassword() async throws {
        script(afterIdentify: [Fix.challengePhone()])
        #expect(try await makeSUT().identify(connection: "db", identifier: .phone(phone))
                == .codeOffered(canUsePassword: false))
    }

    @Test func aFailedIdentify_isReportedLikeAnyOtherFailedStep() async {
        client.authorizeResults = [Fix.needs([Fix.identifyEmail])]
        client.identifyResults = [Fix.terminal("access_denied", description: "authorization_rejected")]
        await #expect(throws: Auth0EmbeddedAuthError.self) {
            try await makeSUT().identify(connection: "db", identifier: .email(email))
        }
    }

    // MARK: A code that follows

    @Test func aCodeFollowsIdentify_withoutSubmittingTheEmailAgain() async throws {
        script(afterIdentify: [Fix.challengeEmail, Fix.verifyPassword])
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        let sut = makeSUT()

        _ = try await sut.identify(connection: "db", identifier: .email(email))
        try await sut.startOTP(connection: "db", identifier: .email(email))

        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1)
        ], "one loop, one identify, then the code")
    }

    @Test func discoveryLoop_isUsedOnceForTheIdentify_andTheCodeThatFollows() async throws {
        script(afterIdentify: [Fix.challengeEmail, Fix.verifyPassword])
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        let sut = makeSUT()

        _ = try await sut.discover()
        _ = try await sut.identify(connection: "db", identifier: .email(email))
        try await sut.startOTP(connection: "db", identifier: .email(email))

        #expect(client.calls.filter { $0 == .authorize(connection: "db") }.count == 1)
    }

    @Test func aCodeFollowsOnlyOnce_aResendStartsFromTheTop() async throws {
        script(afterIdentify: [Fix.challengeEmail, Fix.verifyPassword], loops: 2)
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail]), Fix.needs([Fix.verifyEmail])]
        let sut = makeSUT()

        _ = try await sut.identify(connection: "db", identifier: .email(email))
        try await sut.startOTP(connection: "db", identifier: .email(email))
        try await sut.startOTP(connection: "db", identifier: .email(email))

        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1),
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1)
        ], "the old loop may have ended with its code, so it isn't trusted")
    }

    @Test func aCodeForSomeoneElse_submitsThemFirst() async throws {
        script(afterIdentify: [Fix.challengeEmail, Fix.verifyPassword], loops: 2)
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        let sut = makeSUT()

        _ = try await sut.identify(connection: "db", identifier: .email(email))
        try await sut.startOTP(connection: "db", identifier: .email("someone.else@atko.email"))

        #expect(client.calls.contains(.identify("someone.else@atko.email", type: .email)))
    }

    @Test func afterAWrongPassword_aCodeStartsFromTheTop_becauseTheServerOffersOnlyThePasswordNow() async throws {
        script(afterIdentify: [Fix.challengeEmail, Fix.verifyPassword], loops: 2)
        client.verifyPasswordResults = [
            .failure(Fix.needs([Fix.verifyPassword], subReason: "invalid_identifier_or_password"))
        ]
        client.challengeEmailResults = [Fix.needs([Fix.verifyEmail])]
        let sut = makeSUT()

        _ = try await sut.identify(connection: "db", identifier: .email(email))
        await #expect(throws: AuthFailure.invalidPassword) { try await sut.verifyPassword("wrong") }
        try await sut.startOTP(connection: "db", identifier: .email(email))

        #expect(client.calls == [
            .authorize(connection: "db"), .identify(email, type: .email), .verifyPassword("wrong"),
            .authorize(connection: "db"), .identify(email, type: .email), .challengeEmail(index: 1)
        ])
    }

    @Test func aTextFollowsIdentifyToo() async throws {
        script(afterIdentify: [Fix.challengePhone(index: 2), Fix.verifyPassword])
        client.challengePhoneResults = [Fix.needs([Fix.verifySMS])]
        let sut = makeSUT()

        _ = try await sut.identify(connection: "db", identifier: .phone(phone))
        try await sut.startOTP(connection: "db", identifier: .phone(phone))

        #expect(client.calls == [
            .authorize(connection: "db"), .identify(phone, type: .phone),
            .challengePhone(index: 2, deliveryMethod: .text)
        ])
    }

    // MARK: The password

    @Test func theRightPassword_signsInAnEmailOfferedBoth() async throws {
        script(afterIdentify: [Fix.challengeEmail, Fix.verifyPassword])
        client.verifyPasswordResults = [.success(Credentials(accessToken: "pw"))]
        let sut = makeSUT()

        _ = try await sut.identify(connection: "db", identifier: .email(email))
        #expect(try await sut.verifyPassword("correct horse") == .authenticated)

        #expect(client.calls.last == .verifyPassword("correct horse"))
        #expect(store.delivered.map(\.accessToken) == ["pw"])
        #expect(!client.calls.contains(.challengeEmail(index: 1)), "signing in with a password sends no email")
    }
}
