@testable import Auth0UniversalComponents
import Testing

@Suite
struct LoginRendererTests {

    private let renderer = LoginRenderer()
    private let code = ScreenPlan.otpCode(identifier: .email("a@b.com"))

    private func plan(_ step: LoginStep, channels: [LoginChannel] = [.email]) -> ScreenPlan {
        renderer.plan(for: step, channels: channels)
    }

    @Test func straightThroughSteps() {
        #expect(plan(.loading) == .loading)
        #expect(plan(.collectOTPIdentifier(.email)) == .identifier(.email))
        #expect(plan(.collectOTPCode(identifier: .email("a@b.com"))) == code)
        #expect(plan(.authenticated) == .authenticated)
        #expect(plan(.failed(message: "bad")) == .failed(message: "bad"))
        #expect(plan(.noMethodsAvailable) == .noMethods)
    }

    @Test func payloadChange_keepsTransitionIdentity() {
        #expect(code.transitionIdentity
                == ScreenPlan.otpCode(identifier: .phone("+14155550123"), sentTo: "(4**)***-*900").transitionIdentity)
        #expect(ScreenPlan.identifier(.email).transitionIdentity != code.transitionIdentity)
    }

    @Test func additionalStep_isItsOwnScreen() {
        #expect(plan(.additionalStep) == .additionalStep)
        #expect(code.navigationDepth < ScreenPlan.additionalStep.navigationDepth)
        #expect(ScreenPlan.additionalStep.navigationDepth < ScreenPlan.authenticated.navigationDepth)
    }

    @Test func additionalStepUnavailable_isItsOwnScreen() {
        #expect(plan(.additionalStepUnavailable) == .additionalStepUnavailable)
        #expect(code.navigationDepth < ScreenPlan.additionalStepUnavailable.navigationDepth)
    }

    @Test func navigationDepth_ordersTheFlow() {
        #expect(ScreenPlan.loading.navigationDepth < ScreenPlan.identifier(.email).navigationDepth)
        #expect(ScreenPlan.identifier(.email).navigationDepth < code.navigationDepth)
        #expect(code.navigationDepth < ScreenPlan.authenticated.navigationDepth)
    }

    // MARK: Email and phone

    /// The tenant's first way is the shared screen, listing the others under "OR".
    @Test func firstWay_listsTheOthers() {
        #expect(plan(.collectOTPIdentifier(.email), channels: [.email, .phone])
                == .identifier(.email, alternatives: [.phone], isFirst: true))
        #expect(plan(.collectOTPIdentifier(.phone), channels: [.phone, .email])
                == .identifier(.phone, alternatives: [.email], isFirst: true))
    }

    /// "Continue with Phone" opens the phone's own screen: nothing listed, and one level deeper, so it pushes.
    @Test func anotherWay_isItsOwnScreen_oneLevelDeeper() {
        let phone = plan(.collectOTPIdentifier(.phone), channels: [.email, .phone])
        #expect(phone == .identifier(.phone, alternatives: [], isFirst: false))
        let first = plan(.collectOTPIdentifier(.email), channels: [.email, .phone])
        #expect(first.navigationDepth < phone.navigationDepth)
        #expect(phone.navigationDepth < code.navigationDepth)
        #expect(first.transitionIdentity != phone.transitionIdentity)
    }

    @Test func aSingleWay_isItsOwnScreen() {
        #expect(plan(.collectOTPIdentifier(.phone), channels: [.phone]) == .identifier(.phone))
    }

    @Test func phoneCode_carriesTheServersMask() {
        let step = LoginStep.collectOTPCode(identifier: .phone("+14233530900"), sentTo: "(4**)***-*900")
        #expect(plan(step, channels: [.phone])
                == .otpCode(identifier: .phone("+14233530900"), sentTo: "(4**)***-*900"))
    }

    // MARK: Password

    private let password = ScreenPlan.password(identifier: .username("sarah.doe"))

    @Test func thePasswordStep_isItsOwnScreen_atTheDepthOfCodeEntry() {
        #expect(plan(.collectPassword(identifier: .username("sarah.doe")), channels: [.password]) == password)
        #expect(password.navigationDepth == code.navigationDepth)
        #expect(password.navigationDepth < ScreenPlan.additionalStep.navigationDepth)
        #expect(password.transitionIdentity != code.transitionIdentity)
    }

    @Test func whatWasTyped_doesNotChangeThePasswordScreensIdentity() {
        let other = ScreenPlan.password(identifier: .username("someone.else"))
        #expect(password.transitionIdentity == other.transitionIdentity)
    }

    @Test func passwordOnItsOwn_isItsOwnScreen() {
        #expect(plan(.collectOTPIdentifier(.password), channels: [.password]) == .identifier(.password))
    }

    @Test func passwordFirst_listsTheCodeWaysUnderIt() {
        #expect(plan(.collectOTPIdentifier(.password), channels: [.password, .email, .phone])
                == .identifier(.password, alternatives: [.email, .phone], isFirst: true))
    }

    /// "Continue with Password" opens the username's own screen, one level deeper than the first, so it pushes.
    @Test func passwordAsAnotherWay_isItsOwnScreen_oneLevelDeeper() {
        let own = plan(.collectOTPIdentifier(.password), channels: [.email, .password])
        #expect(own == .identifier(.password, alternatives: [], isFirst: false))
        let first = plan(.collectOTPIdentifier(.email), channels: [.email, .password])
        #expect(first == .identifier(.email, alternatives: [.password], isFirst: true))
        #expect(first.navigationDepth < own.navigationDepth)
        #expect(own.navigationDepth < password.navigationDepth)
    }

    @Test func theUsernameWay_hasItsOwnWords() {
        #expect(LoginChannel.password.title == "Enter your username to get started")
        #expect(LoginChannel.password.continueTitle == "Continue with Password")
    }

    @Test func aPlanCarriesTheAlternativeItsStepOffers() {
        let identifier = LoginIdentifier.email("a@b.com")
        #expect(plan(.collectPassword(identifier: identifier, canSendCode: true))
                == .password(identifier: identifier, canSendCode: true))
        #expect(plan(.collectOTPCode(identifier: identifier, sentTo: nil, canUsePassword: true))
                == .otpCode(identifier: identifier, sentTo: nil, canUsePassword: true))
        #expect(plan(.collectPassword(identifier: identifier))
                != plan(.collectPassword(identifier: identifier, canSendCode: true)))
    }

    @Test func aChangeOfAlternative_isNotANewScreen() {
        let identifier = LoginIdentifier.email("a@b.com")
        #expect(plan(.collectPassword(identifier: identifier, canSendCode: true)).transitionIdentity
                == plan(.collectPassword(identifier: identifier)).transitionIdentity)
    }

    @Test func theCodeAndThePassword_areTheTwoWaysOfTheSameStep() {
        let identifier = LoginIdentifier.email("a@b.com")
        let code = plan(.collectOTPCode(identifier: identifier))
        let password = plan(.collectPassword(identifier: identifier))
        #expect(code.isSibling(of: password))
        #expect(password.isSibling(of: code))
        #expect(!code.isSibling(of: plan(.collectOTPIdentifier(.email))))
        #expect(!password.isSibling(of: password))
    }

    @Test func theWayToACodeInstead_isWordedForWhereItGoes() {
        #expect(LoginChannel.email.sendCodeTitle == "Email me a code")
        #expect(LoginChannel.phone.sendCodeTitle == "Text me a code")
    }

    @Test func eachWay_hasTheLabelItsFieldHasAndTheRowThatShowsItsValue() {
        #expect(LoginChannel.email.fieldLabel == "Email")
        #expect(LoginChannel.phone.fieldLabel == "Phone number")
        #expect(LoginChannel.password.fieldLabel == "Username")
    }

    @Test func aNumber_isShownOnThePasswordScreenAsItWasTyped() {
        #expect(LoginIdentifier.phone("+14233530900").displayValue == "+1 (423)353-0900")
        #expect(LoginIdentifier.email("sarah.doe@atko.email").displayValue == "sarah.doe@atko.email")
        #expect(LoginIdentifier.username("sarah.doe").displayValue == "sarah.doe")
    }

    @Test func aNumberWithNoKnownCountry_isShownAsGiven() {
        #expect(LoginIdentifier.phone("not a number").displayValue == "not a number")
    }

    @Test func aWrongPassword_isWordedForWhatWasTyped() {
        #expect(AuthFailure.invalidPassword.message(for: .email) == "Incorrect email or password. Please try again.")
        #expect(AuthFailure.invalidPassword.message(for: .phone)
                == "Incorrect phone number or password. Please try again.")
        #expect(AuthFailure.invalidPassword.message(for: .password)
                == "Incorrect username or password. Please try again.")
    }

    @Test func aCodeThatCannotBeChecked_needsANewOne() {
        #expect(AuthFailure.codeExpired.needsNewCode)
        #expect(AuthFailure.codeNoLongerValid.needsNewCode)
        #expect(!AuthFailure.invalidCode.needsNewCode)
        #expect(!AuthFailure.tooManyAttempts.needsNewCode)
    }

    @Test func aUsername_isTheIdentifierOfThePasswordWay() {
        #expect(LoginIdentifier.username("sarah.doe").channel == .password)
        #expect(LoginIdentifier.username("sarah.doe").value == "sarah.doe")
    }
}
