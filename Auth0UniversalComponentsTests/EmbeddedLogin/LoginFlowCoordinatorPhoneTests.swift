@testable import Auth0UniversalComponents
import Testing

/// Phone sign-in, and the email-or-phone first screen.
@Suite
@MainActor
struct LoginFlowCoordinatorPhoneTests {

    private let phone = "+14233530900"
    private let masked = "(4**)***-*900"

    private func coordinator(
        offering options: [LoginOption], startOTP: Result<Void, Error>? = .success(()),
        verifyOTP: Result<AuthProgress, Error>? = nil
    ) -> (LoginFlowCoordinator, ScriptedAuthInteractor) {
        let interactor = ScriptedAuthInteractor(discover: .success(options), startOTP: startOTP, verifyOTP: verifyOTP)
        interactor.startOTPSentTo = masked
        return (LoginFlowCoordinator(interactor: interactor), interactor)
    }

    private let emailFirst: [LoginOption] = [.emailOTP(connection: "c"), .phoneOTP(connection: "c")]
    private let phoneFirst: [LoginOption] = [.phoneOTP(connection: "c"), .emailOTP(connection: "c")]

    // MARK: The first screen

    /// The tenant's order decides: its first way is the first screen.
    @Test func theTenantsFirstWay_isTheFirstScreen() async {
        let (emailFirstSUT, _) = coordinator(offering: emailFirst)
        await emailFirstSUT.send(.start)
        #expect(emailFirstSUT.channels == [.email, .phone])
        #expect(emailFirstSUT.step == .collectOTPIdentifier(.email))

        let (phoneFirstSUT, _) = coordinator(offering: phoneFirst)
        await phoneFirstSUT.send(.start)
        #expect(phoneFirstSUT.channels == [.phone, .email])
        #expect(phoneFirstSUT.step == .collectOTPIdentifier(.phone))
    }

    @Test func phoneOnly_startsOnThePhoneScreen() async {
        let (sut, _) = coordinator(offering: [.phoneOTP(connection: "c")])
        await sut.send(.start)
        #expect(sut.channels == [.phone])
        #expect(sut.step == .collectOTPIdentifier(.phone))
    }

    @Test func aRepeatedWay_isListedOnce_whereItFirstAppears() async {
        let (sut, _) = coordinator(offering: emailFirst + [.emailOTP(connection: "c")])
        await sut.send(.start)
        #expect(sut.channels == [.email, .phone])
    }

    // MARK: "Continue with …"

    @Test func continueWithPhone_opensThePhoneScreen_andBackReturns() async {
        let (sut, _) = coordinator(offering: emailFirst)
        await sut.send(.start)
        await sut.send(.chooseChannel(.phone))
        #expect(sut.step == .collectOTPIdentifier(.phone))

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier(.email))
        #expect(sut.goBack() == .exitFlow)
    }

    /// The same, the other way round, when the tenant lists phone first.
    @Test func continueWithEmail_opensTheEmailScreen_andBackReturns() async {
        let (sut, _) = coordinator(offering: phoneFirst)
        await sut.send(.start)
        await sut.send(.chooseChannel(.email))
        #expect(sut.step == .collectOTPIdentifier(.email))

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier(.phone))
    }

    @Test func aWayTheTenantDoesntOffer_isIgnored() async {
        let (sut, _) = coordinator(offering: [.emailOTP(connection: "c")])
        await sut.send(.start)
        await sut.send(.chooseChannel(.phone))
        #expect(sut.step == .collectOTPIdentifier(.email))
    }

    // MARK: The texted code

    @Test func submittingANumber_textsTheCode_andShowsTheServersMask() async {
        let (sut, interactor) = coordinator(offering: emailFirst)
        await sut.send(.start)
        await sut.send(.chooseChannel(.phone))
        await sut.send(.submitIdentifier(.phone(phone)))
        #expect(interactor.receivedRequests.last == .startOTP(connection: "c", identifier: .phone(phone)))
        #expect(sut.step == .collectOTPCode(identifier: .phone(phone), sentTo: masked))
        #expect(sut.enteredIdentifier == .phone(phone))
    }

    /// Back (or Edit) from the code returns to the screen the number was typed on, then to the first screen.
    @Test func backFromTheCode_returnsToThePhoneScreen_thenTheFirstScreen() async {
        let (sut, _) = coordinator(offering: emailFirst)
        await sut.send(.start)
        await sut.send(.chooseChannel(.phone))
        await sut.send(.submitIdentifier(.phone(phone)))

        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier(.phone))
        #expect(sut.goBack() == .movedBack)
        #expect(sut.step == .collectOTPIdentifier(.email))
    }

    @Test func aNumberThatCantBeTexted_staysOnThePhoneScreen() async {
        let (sut, _) = coordinator(offering: emailFirst, startOTP: .failure(AuthFailure.codeNotSent))
        await sut.send(.start)
        await sut.send(.chooseChannel(.phone))
        await sut.send(.submitIdentifier(.phone(phone)))
        #expect(sut.step == .collectOTPIdentifier(.phone))
        #expect(sut.inputError == .codeNotSent)
    }

    /// An expired code stays on the code screen; Resend texts the same number and clears the error.
    @Test func anExpiredCode_staysInline_andResendTextsAgain() async {
        let (sut, interactor) = coordinator(offering: [.phoneOTP(connection: "c")],
                                            verifyOTP: .failure(AuthFailure.codeExpired))
        await sut.send(.start)
        await sut.send(.submitIdentifier(.phone(phone)))
        await sut.send(.submitOTP(code: "123456"))
        #expect(sut.step == .collectOTPCode(identifier: .phone(phone), sentTo: masked))
        #expect(sut.inputError == .codeExpired)

        await sut.resendOTP()
        #expect(sut.inputError == nil)
        #expect(interactor.receivedRequests.filter { $0 == .startOTP(connection: "c", identifier: .phone(phone)) }
                    .count == 2)
        #expect(sut.step == .collectOTPCode(identifier: .phone(phone), sentTo: masked))
    }

    /// Choosing another way drops the first screen's error: it belonged to what was typed there.
    @Test func choosingAnotherWay_clearsTheError() async {
        let (sut, _) = coordinator(offering: emailFirst, startOTP: .failure(AuthFailure.codeNotSent))
        await sut.send(.start)
        await sut.send(.submitIdentifier(.email("user@example.com")))
        #expect(sut.inputError == .codeNotSent)
        await sut.send(.chooseChannel(.phone))
        #expect(sut.inputError == nil)
        #expect(sut.step == .collectOTPIdentifier(.phone))
    }
}
