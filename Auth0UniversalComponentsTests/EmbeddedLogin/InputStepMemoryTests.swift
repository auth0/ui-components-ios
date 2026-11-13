@testable import Auth0UniversalComponents
import Testing

/// The screen that stays on display while a request is on its way, and what it still offers.
@Suite
struct InputStepMemoryTests {

    private let email = LoginIdentifier.email("sarah.doe@atko.email")

    @Test func whileLoading_theLastInputScreenStaysWithTheAlternativeItOffers() {
        var memory = InputStepMemory()
        let password = LoginStep.collectPassword(identifier: email, canSendCode: true)
        memory.track(password)
        memory.track(.loading)

        #expect(memory.displayed(for: .loading) == password)
    }

    @Test func aNewInputScreen_replacesTheOldOne() {
        var memory = InputStepMemory()
        memory.track(.collectPassword(identifier: email, canSendCode: true))
        let code = LoginStep.collectOTPCode(identifier: email, sentTo: nil, canUsePassword: true)
        memory.track(code)
        memory.track(.loading)

        #expect(memory.displayed(for: .loading) == code)
    }

    @Test func anyOtherStep_isShownAsItIs_andForgetsTheScreen() {
        var memory = InputStepMemory()
        memory.track(.collectOTPCode(identifier: email, sentTo: nil, canUsePassword: true))

        #expect(memory.displayed(for: .authenticated) == .authenticated)
        memory.track(.authenticated)
        #expect(memory.displayed(for: .loading) == .loading, "nothing to hold on to after the sign-in is over")
    }

    @Test func withNothingRemembered_loadingIsLoading() {
        #expect(InputStepMemory().displayed(for: .loading) == .loading)
    }
}
