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
}
