import Auth0
import Testing
@testable import Auth0UniversalComponents

@Suite struct SignupOfferTests {

    private func offer(_ identifiers: (IdentifierType, Bool)...) -> SignupOffer {
        SignupOffer(identifiers.map { SignupIdentifier(type: $0.0, isRequired: $0.1) })
    }

    @Test func aRequiredEmail_isSupported() {
        #expect(offer((.email, true)).isSupported)
    }

    @Test func anOptionalPhone_besideARequiredEmail_isLeftOut_butSupported() {
        #expect(offer((.email, true), (.phone, false)).isSupported)
    }

    @Test(arguments: [
        [(IdentifierType.phone, true)],                       // a kind with no screens yet
        [(IdentifierType.email, true), (.phone, true)],       // two required: not before several are supported
        [(IdentifierType.email, false)],                      // nothing required
        []
    ] as [[(IdentifierType, Bool)]])
    func anythingElse_isNotSupported(identifiers: [(IdentifierType, Bool)]) {
        let offer = SignupOffer(identifiers.map { SignupIdentifier(type: $0.0, isRequired: $0.1) })
        #expect(!offer.isSupported)
    }
}

@Suite struct SignupMenuTests {

    @Test func theMenuAfterSignup_asksForTheEmail() {
        let menu = SignupMenu([.identifyEmail])
        #expect(menu.askedFor == [.email])
        #expect(menu.challenge == nil)
        #expect(!menu.canConfirm)
    }

    @Test func theMenuAfterIdentify_offersACode_andStillAllowsEditing() {
        let menu = SignupMenu([.challengeEmail(index: 0, identifier: "us**@ex***.com"), .identifyEmail])
        #expect(menu.challenge == SignupChallenge(kind: .email, index: 0))
        #expect(menu.askedFor == [.email])
        #expect(!menu.canConfirm)
    }

    @Test func theMenuAfterTheCode_offersToCreateTheAccount() {
        let menu = SignupMenu([.confirmSignup])
        #expect(menu.canConfirm)
        #expect(menu.askedFor.isEmpty)
        #expect(menu.challenge == nil)
    }

    @Test func entriesThatAreNotSignups_areIgnored() {
        let menu = SignupMenu([.verifyOTP(channel: .email, identifier: nil), .identifyPhone, .unknown(rawAction: "x")])
        #expect(menu == SignupMenu([]))
    }
}

@Suite struct SignupFailureTests {

    private typealias Fixtures = EmbeddedAuthFixtures

    @Test(arguments: [
        (Fixtures.needs([Fixtures.identifyEmail], subReason: "invalid_email"), SignupFailure.invalidEmail),
        (Fixtures.needs([Fixtures.verifyEmail], subReason: "invalid_identifier_or_code"), .invalidCode),
        (Fixtures.needs([Fixtures.verifyEmail], subReason: "invalid_code"), .invalidCode),
        (Fixtures.rateLimited, .tooManyAttempts),
        (Fixtures.terminal("session_expired", description: "expired"), .ended),
        (Fixtures.terminal("server_error", description: "boom", statusCode: 500), .ended),
        (Fixtures.terminal("invalid_request", description: "bad", statusCode: 400), .ended),
        (Fixtures.terminal("access_denied", description: "too_many_wrong_otp_attempts"), .tooManyWrongCodes),
        (Fixtures.terminal("access_denied", description: "too_many_resend_attempts"), .tooManyCodesRequested),
        (Fixtures.terminal("access_denied", description: "challenge_expired"), .codeExpired),
        (Fixtures.terminal("access_denied", description: "denied"), .denied)
    ] as [(EmbeddedAuthError, SignupFailure)])
    func theServersAnswer_isReadAsTheRightFailure(error: EmbeddedAuthError, expected: SignupFailure) {
        #expect(SignupFailure(error) == expected)
    }

    @Test func aPlainContinuation_isNotAFailure() {
        #expect(SignupFailure(Fixtures.needs([Fixtures.identifyEmail])) == nil)
        #expect(SignupFailure(Fixtures.network) == nil)
    }

    /// The SDK clears its session on every failure but a continuation or a network error, so only those can go on.
    @Test func onlyTheOnesTheUserCanFix_stayOnTheScreen() {
        let stays: [SignupFailure] = [.invalidEmail, .invalidCode, .codeNotSent]
        let ends: [SignupFailure] = [.tooManyAttempts, .tooManyWrongCodes, .codeExpired, .tooManyCodesRequested,
                                     .denied, .ended]
        #expect(stays.allSatisfy { !$0.endsSignup })
        #expect(ends.allSatisfy { $0.endsSignup })
    }
}
