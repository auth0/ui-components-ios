import SwiftUI

/// Phone entry: country, number and Continue. Formats the number as it's typed when the country has a mask, and hands
/// it on in E.164 form. Continue is off while the format check's error shows, but not after a server error, so the
/// same number can be tried again. The country and number are the host's.
struct LoginPhoneForm: View {
    @Binding var country: Country?
    @Binding var number: String
    let isLoading: Bool
    /// The server's error (e.g. the code couldn't be sent). Hidden once the user edits.
    let serverError: String?
    /// The bottom of the screen (a phone-only screen), or right under the field (the first of several ways).
    var pinsContinueToBottom = false
    /// Receives the number in E.164 form, e.g. `+14155550123`.
    let onContinue: (String) -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var errors = LoginFieldErrors()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginPhoneField(country: $country, number: $number, error: errors.shown(server: serverError),
                            isEnabled: !isLoading, isFocused: $isFocused, onSubmit: submit)
            if pinsContinueToBottom { Spacer(minLength: theme.spacing.xl) }
            LoginPrimaryButton("Continue", isLoading: isLoading,
                               isEnabled: !number.isEmpty && country != nil && errors.validation == nil,
                               action: submit)
                .padding(.top, pinsContinueToBottom ? 0 : theme.spacing.md)
        }
        .onAppear { isFocused = true }
        .onChangeCompat(of: number) { typed in
            let formatted = PhoneNumberFormatter.format(typed, mask: country?.format)
            // Setting it comes back here once more, with nothing left to format.
            guard formatted == typed else { number = formatted; return }
            errors.userEdited()
        }
        // A new country brings its own mask, and can make a rejected number right.
        .onChangeCompat(of: country?.flag) { _ in
            number = Self.reformatted(number, for: country)
            errors.userEdited()
        }
        .onChangeCompat(of: serverError) { if $0 != nil { errors.serverReported() } }
    }

    /// `number` laid out for the country just picked. One typed with its own `+` names its country, so it stays as is.
    static func reformatted(_ number: String, for country: Country?) -> String {
        guard !PhoneNumberFormatter.isInternational(number) else { return number }
        return PhoneNumberFormatter.format(PhoneNumberFormatter.digits(number), mask: country?.format)
    }

    /// What a phone form starts with: a stored E.164 number split into its country and formatted, or the device's
    /// country and the text as given. Set in the host's `init`, so it never counts as an edit and can't hide an error.
    static func startingEntry(for number: String) -> (country: Country?, number: String) {
        let entry = CountryStore.phoneEntry(for: number)
        return (entry.country, PhoneNumberFormatter.format(entry.number, mask: entry.country?.format))
    }

    private func submit() {
        // Return on the keyboard bypasses the button's guards.
        guard !isLoading, errors.validation == nil else { return }
        guard let country,
              let e164 = PhoneNumberValidator.e164(dialCode: country.code, number: number, mask: country.format) else {
            errors.validation = "Please enter a valid phone number."
            return
        }
        onContinue(e164)
    }
}
