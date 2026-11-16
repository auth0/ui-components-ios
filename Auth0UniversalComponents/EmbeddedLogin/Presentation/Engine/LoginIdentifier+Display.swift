extension LoginIdentifier {
    /// How the password screen's row shows it: a number split into its country code and formatted as it was typed
    /// (`+1 (423)353-0900`), an email or username as it is.
    var displayValue: String {
        // A number from the phone form is always E.164; anything else is shown as given.
        guard case let .phone(number) = self, number.hasPrefix("+") else { return value }
        let entry = CountryStore.phoneEntry(for: number)
        guard let country = entry.country else { return number }
        return "\(country.code) \(PhoneNumberFormatter.format(entry.number, mask: country.format))"
    }
}
