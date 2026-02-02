import Foundation
import Combine

/// Struct representing a country with its name, phone code, and flag emoji.
struct Country: Codable, Identifiable {
    let id = UUID()
    let name: String
    let code: String
    let flag: String
    
    enum CodingKeys: String, CodingKey {
        case name, code, flag
    }
}

/// ObservableObject managing the list of countries loaded from a JSON resource.
final class CountryStore: ObservableObject {
    @Published var countries: [Country] = []
    
    init() {
        self.countries = Self.loadCountries()
    }

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

