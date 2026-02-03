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

    enum CodingKeys: String, CodingKey {
        case name, code, flag
    }
}

/// Store for managing the list of countries and their codes.
///
/// This class loads the country data from CountryCodes.json in the framework bundle
/// and publishes it for use in SwiftUI views. It handles loading failures gracefully.
final class CountryStore: ObservableObject {
    /// The list of available countries with their calling codes
    @Published var countries: [Country] = []

    /// Initializes the store and loads countries from the JSON file.
    init() {
        self.countries = Self.loadCountries()
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
}

