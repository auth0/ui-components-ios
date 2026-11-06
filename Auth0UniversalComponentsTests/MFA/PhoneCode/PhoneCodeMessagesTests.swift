@testable import Auth0UniversalComponents
import Testing

/// The words of the code screen, which depend on how the code was sent.
@Suite
struct PhoneCodeMessagesTests {

    private let sut = PhoneCodeChallengeMessages.defaults

    @Test(arguments: [(PhoneCodeDelivery.text, "From (4**)***-*900"), (.voice, "Calling (4**)***-*900")])
    func aPhoneNumber_isNamedInTheSubtitle(_ delivery: PhoneCodeDelivery, _ expected: String) {
        #expect(sut.subtitle(destination: "(4**)***-*900", delivery: delivery) == expected)
    }

    /// The same line the sign-in's code screen shows for an emailed code.
    @Test func anAddress_isNamedInTheSubtitle() {
        #expect(sut.subtitle(destination: "sa**@atko.email", delivery: .email) == "From sa**@atko.email")
    }

    @Test(arguments: [
        (PhoneCodeDelivery.text, "We texted a code to your phone."),
        (.voice, "We're calling your phone with a code."),
        (.email, "We emailed a code to your inbox.")
    ])
    func noDestination_getsAnUnnamedLine(_ delivery: PhoneCodeDelivery, _ expected: String) {
        #expect(sut.subtitle(destination: "", delivery: delivery) == expected)
    }

    /// The sign-in's own words for a wrong code, by where the code went.
    @Test(arguments: [
        (PhoneCodeDelivery.text, "Invalid Code. Please double check the code sent to your phone."),
        (.voice, "Invalid Code. Please double check the code sent to your phone."),
        (.email, "Invalid Code. Please double check the code sent to your email.")
    ])
    func aWrongCode_namesWhereTheCodeWent(_ delivery: PhoneCodeDelivery, _ expected: String) {
        #expect(sut.copy(for: delivery).invalidCode == expected)
        #expect(AuthFailure.invalidCode.message(for: delivery == .email ? .email : .phone) == expected,
                "the same as the sign-in")
    }

    @Test(arguments: [
        (PhoneCodeDelivery.text, "Text message", "Get a code by text message."),
        (.voice, "Voice call", "Get a code by phone call."),
        (.email, "Email", "Get a code by email.")
    ])
    func eachKindHasItsOwnRow(_ delivery: PhoneCodeDelivery, _ title: String, _ description: String) {
        #expect(sut.copy(for: delivery).row.title == title)
        #expect(sut.copy(for: delivery).row.description == description)
    }

    @Test func theWordsCanBeChangedPerDelivery() {
        let messages = MfaMessages.default.with { $0.phoneCodeChallenge.email.invalidCode = "Nope." }
        #expect(messages.phoneCodeChallenge.email.invalidCode == "Nope.")
        #expect(messages.phoneCodeChallenge.text.invalidCode.hasSuffix("your phone."), "the others keep theirs")
    }
}
