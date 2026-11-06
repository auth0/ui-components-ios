import Foundation
import Combine

/// Represents a country with its calling code and flag emoji.
///
/// Used for country selection in phone number enrollment forms.
/// The ID is generated locally and is not decoded from JSON.
struct Country: Codable, Identifiable {
    /// Unique identifier for the country
    let id = UUID()
    /// The full name of the country (e.g., "United States")
    let name: String
    /// The international calling code (e.g., "+1")
    let code: String
    /// The flag emoji for the country (e.g., "🇺🇸")
    let flag: String
    /// How a national number is laid out as it's typed, `#` for each digit (e.g. "(###)###-####"). `nil` when the
    /// country has none yet: its numbers are shown as typed and only loosely checked.
    var format: String?

    enum CodingKeys: String, CodingKey {
        case name, code, flag, format
    }
}

/// Store for managing the list of countries and their codes.
///
/// This class loads the country data from CountryCodes.json in the framework bundle
/// and publishes it for use in SwiftUI views. It handles loading failures gracefully.
final class CountryStore: ObservableObject {
    /// The list of available countries with their calling codes
    @Published var countries: [Country] = []

    /// Decoded once: the list never changes while the app runs, and each country keeps the same `id`.
    static let all: [Country] = loadCountries()

    /// Initializes the store with the countries from the JSON file.
    init() {
        self.countries = Self.all
    }

    /// Loads countries from the CountryCodes.json file in the resource bundle.
    ///
    /// - Returns: An array of countries if successfully loaded, otherwise an empty array
    ///
    /// - Note: Silently returns an empty array if the JSON file cannot be found or decoded
    static func loadCountries() -> [Country] {
        guard let url = ResourceBundle.default.url(forResource: "CountryCodes", withExtension: "json") else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let countries = try JSONDecoder().decode([Country].self, from: data)
            return countries
        } catch {
            return []
        }
    }

    /// The country of `region` (an ISO 3166 code such as `"US"`), found by its flag: flags are unique in the list,
    /// and the list carries no region codes. `nil` when there is no region or it isn't listed.
    static func country(forRegion region: String?, in countries: [Country]) -> Country? {
        guard let flag = region.flatMap(flag(forRegion:)) else { return nil }
        return countries.first { $0.flag == flag }
    }

    /// The device's country, else the United States.
    static func defaultCountry(in countries: [Country] = all,
                               region: String? = Locale.current.region?.identifier) -> Country? {
        country(forRegion: region, in: countries) ?? country(forRegion: "US", in: countries)
    }

    /// Splits an E.164 number (`+14155550123`) into its country and the digits after the country code, to pre-fill a
    /// phone field. The longest matching code wins (`+1-876` before `+1`); among countries sharing it, `region`'s
    /// country, else the United States (as for `defaultCountry`), else the first listed. `nil` when no code matches.
    static func split(_ e164: String, in countries: [Country],
                      region: String? = Locale.current.region?.identifier) -> (country: Country, national: String)? {
        guard e164.hasPrefix("+") else { return nil }
        let digits = String(e164.filter { $0.isASCII && $0.isNumber })
        func dialDigits(_ country: Country) -> String { String(country.code.filter { $0.isASCII && $0.isNumber }) }
        let matches = countries.filter { !dialDigits($0).isEmpty && digits.hasPrefix(dialDigits($0)) }
        guard let longest = matches.map({ dialDigits($0).count }).max() else { return nil }
        let best = matches.filter { dialDigits($0).count == longest }
        let preferredFlags = [region, "US"].compactMap { $0.flatMap(flag(forRegion:)) }
        let country = preferredFlags.lazy.compactMap { flag in best.first { $0.flag == flag } }.first ?? best[0]
        return (country, String(digits.dropFirst(longest)))
    }

    /// What a phone field starts with: a stored E.164 number split back into country and digits, or the device's
    /// country and the text as given.
    static func phoneEntry(for number: String) -> (country: Country?, number: String) {
        let countries = all
        if let split = split(number, in: countries) { return (split.country, split.national) }
        return (defaultCountry(in: countries), number)
    }

    /// A flag emoji is the region's two letters as regional indicator symbols.
    static func flag(forRegion region: String) -> String? {
        let letters = region.uppercased().unicodeScalars
        guard letters.count == 2, letters.allSatisfy({ ("A"..."Z").contains($0) }) else { return nil }
        var flag = ""
        for letter in letters {
            guard let symbol = Unicode.Scalar(0x1F1E6 + letter.value - 0x41) else { return nil }
            flag.unicodeScalars.append(symbol)
        }
        return flag
    }
}
