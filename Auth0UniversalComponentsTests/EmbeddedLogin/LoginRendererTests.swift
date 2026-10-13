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

    @Test func stepUpMFA_carriesFactorAndDestination() {
        let email = MFAChallenge(factor: .email, destination: "s***@atko.email")
        #expect(plan(.stepUpMFA(email)) == .mfaCode(factor: .email, destination: "s***@atko.email"))
        #expect(plan(.stepUpMFA(MFAChallenge(factor: .otp))) == .mfaCode(factor: .otp, destination: nil))
    }

    @Test func payloadChange_keepsTransitionIdentity() {
        #expect(ScreenPlan.otpCode(identifier: "a").transitionIdentity
                == ScreenPlan.otpCode(identifier: "b").transitionIdentity)
        #expect(ScreenPlan.identifier.transitionIdentity != ScreenPlan.otpCode(identifier: "a").transitionIdentity)
    }

    @Test func navigationDepth_ordersTheFlow() {
        #expect(ScreenPlan.loading.navigationDepth < ScreenPlan.identifier.navigationDepth)
        #expect(ScreenPlan.identifier.navigationDepth < ScreenPlan.otpCode(identifier: "a").navigationDepth)
        #expect(ScreenPlan.otpCode(identifier: "a").navigationDepth < ScreenPlan.authenticated.navigationDepth)
    }

    @Test func codeSourceHint_prefersDestination() {
        #expect(MFAFactor.email.codeSourceHint(destination: "s***@x.com") == "From s***@x.com")
        #expect(MFAFactor.otp.codeSourceHint(destination: nil) == "From your authenticator app")
        #expect(MFAFactor.email.codeSourceHint(destination: "") == "From the code sent to your email")
    }
}
