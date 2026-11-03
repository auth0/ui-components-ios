@testable import Auth0UniversalComponents
import Testing

@Suite
struct LoginRendererTests {

    private let renderer = LoginRenderer()

    private func plan(_ step: LoginStep) -> ScreenPlan {
        renderer.plan(for: step)
    }

    @Test func straightThroughSteps() {
        #expect(plan(.loading) == .loading)
        #expect(plan(.collectOTPIdentifier) == .identifier)
        #expect(plan(.collectOTPCode(identifier: "a@b.com")) == .otpCode(identifier: "a@b.com"))
        #expect(plan(.authenticated) == .authenticated)
        #expect(plan(.failed(message: "bad")) == .failed(message: "bad"))
        #expect(plan(.noMethodsAvailable) == .noMethods)
    }

    @Test func payloadChange_keepsTransitionIdentity() {
        #expect(ScreenPlan.otpCode(identifier: "a").transitionIdentity
                == ScreenPlan.otpCode(identifier: "b").transitionIdentity)
        #expect(ScreenPlan.identifier.transitionIdentity != ScreenPlan.otpCode(identifier: "a").transitionIdentity)
    }

    @Test func additionalStep_isItsOwnScreen() {
        #expect(plan(.additionalStep) == .additionalStep)
        #expect(ScreenPlan.otpCode(identifier: "a").navigationDepth < ScreenPlan.additionalStep.navigationDepth)
        #expect(ScreenPlan.additionalStep.navigationDepth < ScreenPlan.authenticated.navigationDepth)
    }

    @Test func additionalStepUnavailable_isItsOwnScreen() {
        #expect(plan(.additionalStepUnavailable) == .additionalStepUnavailable)
        #expect(ScreenPlan.otpCode(identifier: "a").navigationDepth
                < ScreenPlan.additionalStepUnavailable.navigationDepth)
    }

    @Test func navigationDepth_ordersTheFlow() {
        #expect(ScreenPlan.loading.navigationDepth < ScreenPlan.identifier.navigationDepth)
        #expect(ScreenPlan.identifier.navigationDepth < ScreenPlan.otpCode(identifier: "a").navigationDepth)
        #expect(ScreenPlan.otpCode(identifier: "a").navigationDepth < ScreenPlan.authenticated.navigationDepth)
    }}
