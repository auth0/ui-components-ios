@testable import Auth0UniversalComponents
import Foundation
import Testing

@Suite
struct PhoneNumberValidatorTests {

    @Test func joinsTheCountryCodeAndTheNumber_ignoringFormatting() {
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "(415) 555-0123") == "+14155550123")
        #expect(PhoneNumberValidator.e164(dialCode: "+44", number: " 7700 900123 ") == "+447700900123")
    }

    /// A number typed with its own `+` is already international: the picked country isn't added again.
    @Test func aLeadingPlus_ignoresThePickedCountry() {
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "+44 7700 900123") == "+447700900123")
    }

    /// The 0 people write at home is a trunk prefix: it isn't part of the number dialled from abroad.
    @Test(arguments: [("+44", "07700 900123", "+447700900123"),
                      ("+49", "030 1234567", "+49301234567"),
                      ("+91", "098765 43210", "+919876543210")])
    func aLeadingTrunkZero_isDropped(_ dialCode: String, _ typed: String, _ expected: String) {
        #expect(PhoneNumberValidator.e164(dialCode: dialCode, number: typed) == expected)
    }

    /// Where the 0 belongs to the number, it stays.
    @Test(arguments: [("+39", "06 1234 5678", "+390612345678"),
                      ("+378", "0549 123456", "+3780549123456"),
                      ("+225", "07 12 34 56 78", "+2250712345678")])
    func aZeroThatIsPartOfTheNumber_isKept(_ dialCode: String, _ typed: String, _ expected: String) {
        #expect(PhoneNumberValidator.e164(dialCode: dialCode, number: typed) == expected)
    }

    /// `00` is an international prefix, not a number: not guessed at.
    @Test(arguments: ["0044 7700 900123", "00 7700 900123", "00", "0"])
    func anInternationalPrefixOrAloneZero_isRejected(_ typed: String) {
        #expect(PhoneNumberValidator.e164(dialCode: "+44", number: typed) == nil)
    }

    @Test func aNumberWithItsOwnPlus_keepsEverythingAsTyped() {
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "+39 06 1234 5678") == "+390612345678")
    }

    @Test func rejectsTooShortTooLongAndLetters() {
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "123") == nil)
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "") == nil)
        // 16 digits with the country code: over E.164's 15.
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "123456789012345") == nil)
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "415 555 CALL") == nil)
    }
}

@Suite
struct CountryLookupTests {

    @Test func aRegionsFlag_isItsLettersAsRegionalIndicators() {
        #expect(CountryStore.flag(forRegion: "US") == "🇺🇸")
        #expect(CountryStore.flag(forRegion: "in") == "🇮🇳")
        #expect(CountryStore.flag(forRegion: "USA") == nil)
        #expect(CountryStore.flag(forRegion: "1A") == nil)
    }

    @Test func findsTheDevicesCountry_elseTheUnitedStates() {
        let countries = CountryStore.loadCountries()
        #expect(!countries.isEmpty, "CountryCodes.json didn't load")
        #expect(CountryStore.defaultCountry(in: countries, region: "GB")?.code == "+44")
        // +1 is shared: the flag tells Canada from the United States.
        #expect(CountryStore.defaultCountry(in: countries, region: "CA")?.name == "Canada")
        #expect(CountryStore.defaultCountry(in: countries, region: "ZZ")?.name == "United States")
        #expect(CountryStore.defaultCountry(in: countries, region: nil)?.name == "United States")
    }
}

@Suite
struct LoginFieldErrorsTests {

    @Test func showsTheFormsOwnCheckBeforeTheServers() {
        var errors = LoginFieldErrors()
        errors.validation = "Please enter a valid email address."
        #expect(errors.shown(server: "Server said no") == "Please enter a valid email address.")
    }

    @Test func editingHidesBoth_untilTheServerReportsAgain() {
        var errors = LoginFieldErrors()
        errors.validation = "Please enter a valid email address."
        errors.userEdited()
        #expect(errors.shown(server: "Server said no") == nil)
        errors.serverReported()
        #expect(errors.shown(server: "Server said no") == "Server said no")
    }
}

@Suite
struct PhoneNumberFormatterTests {

    private let usMask = "(###)###-####"

    @Test func laysTheDigitsOnTheMask() {
        #expect(PhoneNumberFormatter.format("4233530900", mask: usMask) == "(423)353-0900")
        #expect(PhoneNumberFormatter.format("423 353 0900", mask: usMask) == "(423)353-0900")
    }

    /// A literal shows only once a digit follows it, so a part-typed number has no dangling `)` or `-`.
    @Test func partlyTyped_hasNoDanglingLiterals() {
        #expect(PhoneNumberFormatter.format("4", mask: usMask) == "(4")
        #expect(PhoneNumberFormatter.format("423", mask: usMask) == "(423")
        #expect(PhoneNumberFormatter.format("4233", mask: usMask) == "(423)3")
        #expect(PhoneNumberFormatter.format("", mask: usMask) == "")
    }

    @Test func formattingTwice_changesNothing() {
        let once = PhoneNumberFormatter.format("4233530900", mask: usMask)
        #expect(PhoneNumberFormatter.format(once, mask: usMask) == once)
    }

    @Test func noMask_orOwnPlus_isLeftAsTyped() {
        #expect(PhoneNumberFormatter.format("7700 900123", mask: nil) == "7700 900123")
        #expect(PhoneNumberFormatter.format("+44 7700 900123", mask: usMask) == "+44 7700 900123")
    }

    @Test func digitsPastTheMask_areKept() {
        #expect(PhoneNumberFormatter.format("42335309001", mask: usMask) == "(423)353-09001")
    }
}

@Suite
struct PhoneNumberMaskValidationTests {

    private let usMask = "(###)###-####"

    @Test func aMaskedCountry_needsEveryDigit() {
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "(423)353-0900", mask: usMask) == "+14233530900")
        // The design's client-side error example.
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "(423)35323", mask: usMask) == nil)
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "(423)353-09001", mask: usMask) == nil)
    }

    @Test func ownPlus_skipsTheMask() {
        #expect(PhoneNumberValidator.e164(dialCode: "+1", number: "+44 7700 900123", mask: usMask) == "+447700900123")
    }

    /// The Caribbean codes are written `+1-876` in the list; only their digits are dialled.
    @Test func dialCodeWithADash_usesItsDigits() {
        #expect(PhoneNumberValidator.e164(dialCode: "+1-876", number: "555 0123") == "+18765550123")
    }
}

@Suite
struct PhoneNumberSplitTests {

    private let countries = CountryStore.loadCountries()

    @Test func splitsIntoCountryAndTheRest() {
        let split = CountryStore.split("+447700900123", in: countries, region: "US")
        #expect(split?.country.name == "United Kingdom")
        #expect(split?.national == "7700900123")
    }

    /// `+1` is shared: the device's country decides, else the United States.
    @Test func aSharedCode_prefersTheDevicesCountry() {
        #expect(CountryStore.split("+14155550123", in: countries, region: "CA")?.country.name == "Canada")
        #expect(CountryStore.split("+14155550123", in: countries, region: "GB")?.country.name == "United States")
        #expect(CountryStore.split("+14155550123", in: countries, region: "US")?.national == "4155550123")
    }

    @Test func theLongestCodeWins() {
        let split = CountryStore.split("+18765550123", in: countries, region: "US")
        #expect(split?.country.code == "+1-876")
        #expect(split?.national == "5550123")
    }

    @Test func notInternational_isNotSplit() {
        #expect(CountryStore.split("4155550123", in: countries, region: "US") == nil)
    }

    @Test func theUnitedStates_hasTheDesignsMask() {
        #expect(countries.first { $0.name == "United States" }?.format == "(###)###-####")
    }
}

@Suite
struct AuthFailurePhoneCopyTests {

    @Test func phoneWords_sayPhone() {
        #expect(AuthFailure.invalidCode.message(for: .phone)
                == "Invalid Code. Please double check the code sent to your phone.")
        #expect(AuthFailure.codeNotSent.message(for: .phone)
                == "We couldn't send your code. Please confirm the phone number is correct and try again.")
        #expect(AuthFailure.codeExpired.message(for: .phone)
                == "Your code has expired. Resend another code and try again.")
    }

    @Test func emailWords_areUnchanged() {
        #expect(AuthFailure.invalidCode.message(for: .email)
                == "Invalid Code. Please double check the code sent to your email.")
        #expect(AuthFailure.codeNotSent.message(for: .email)
                == "We couldn't send your code. Please confirm the email address is correct and try again.")
    }
}

#if canImport(UIKit)
import UIKit

@Suite
struct LoginIconAssetTests {

    /// A missing or renamed asset leaves an empty slot with only a log line, so check it ships. (The module name is
    /// spelled out: this target shadows `ResourceBundle` with a mock.)
    @Test func thePhoneIcon_shipsAtItsDesignSize() throws {
        let image = try #require(UIImage(named: "phone", in: Auth0UniversalComponents.ResourceBundle.default,
                                                 with: nil))
        #expect(image.size == CGSize(width: 11, height: 15))
    }

    /// The envelope is exported larger than the phone icon; the button fits both to the same height.
    @Test func theEmailIcon_ships() throws {
        let image = try #require(UIImage(named: "email", in: Auth0UniversalComponents.ResourceBundle.default,
                                         with: nil))
        #expect(image.size == CGSize(width: 24, height: 22))
    }
}
#endif

/// The phone screens' starting state, set in `init` so it never looks like an edit (which hid the server's error).
@Suite
@MainActor
struct PhoneStartingEntryTests {

    @Test func aStoredNumber_comesBackSplitAndFormatted() {
        let entry = LoginPhoneForm.startingEntry(for: "+14233530900")
        #expect(entry.country?.name == "United States")
        #expect(entry.number == "(423)353-0900")
    }

    @Test func anotherCountrysNumber_keepsItsCountry() {
        let entry = LoginPhoneForm.startingEntry(for: "+447700900123")
        #expect(entry.country?.name == "United Kingdom")
        #expect(entry.number == "7700900123")      // no UK mask yet: digits as given
    }

    @Test func noNumber_startsEmpty_onACountry() {
        let entry = LoginPhoneForm.startingEntry(for: "")
        #expect(entry.country != nil)
        #expect(entry.number.isEmpty)
    }

    /// Decoded once, so a country is the same value each time the picker opens.
    @Test func theCountryList_isDecodedOnce() {
        #expect(!CountryStore.all.isEmpty)
        #expect(CountryStore().countries.map(\.id) == CountryStore().countries.map(\.id))
    }
}

/// Digits in any script are understood; other numerals are rejected, never dropped.
@Suite
struct PhoneDigitScriptTests {

    @Test func otherScripts_becomeOrdinaryDigits() {
        #expect(PhoneNumberFormatter.digits("٠٥٠١٢٣٤٥٦٧") == "0501234567")
        #expect(PhoneNumberFormatter.digits("４１５５５５０１２３") == "4155550123")
        #expect(PhoneNumberFormatter.digits("४१५५५५०१२३") == "4155550123")
    }

    @Test func aNumberInAnotherScript_isAccepted() {
        #expect(PhoneNumberValidator.e164(dialCode: "+20", number: "١٠٠١٢٣٤٥٦٧") == "+201001234567")
    }

    @Test func fullWidthDigits_formatOnTheMask() {
        #expect(PhoneNumberFormatter.format("４２３３５３０９００", mask: "(###)###-####") == "(423)353-0900")
    }

    @Test(arguments: ["½1234", "五五五五", "④①⑤⑤", "²³⁴⁵", "Ⅷ123"])
    func otherNumerals_areRejected(_ typed: String) {
        #expect(PhoneNumberValidator.e164(dialCode: "+20", number: typed) == nil)
    }
}

/// Picking another country must not turn an international number into a national one.
@Suite
@MainActor
struct PhoneCountryChangeTests {

    private let countries = CountryStore.loadCountries()
    private func country(_ name: String) -> Country? { countries.first { $0.name == name } }

    @Test func anInternationalNumber_isLeftAloneWhenTheCountryChanges() {
        for name in ["United Kingdom", "United States", "Germany"] {
            #expect(LoginPhoneForm.reformatted("+447911123456", for: country(name)) == "+447911123456")
            #expect(LoginPhoneForm.reformatted(" +44 7911 123456", for: country(name)) == " +44 7911 123456")
        }
    }

    @Test func anInternationalNumber_stillMeansTheSameNumberAfterThePick() {
        let britain = country("United Kingdom")
        let shown = LoginPhoneForm.reformatted("+447911123456", for: britain)
        let typed = PhoneNumberValidator.e164(dialCode: britain?.code ?? "", number: shown, mask: britain?.format)
        #expect(typed == "+447911123456")
    }

    @Test func aNationalNumber_isLaidOutOnTheNewCountrysMask() {
        let america = country("United States")
        #expect(LoginPhoneForm.reformatted("4233530900", for: america) == "(423)353-0900")
        #expect(LoginPhoneForm.reformatted("(423)353-0900", for: country("United Kingdom")) == "4233530900")
    }
}
