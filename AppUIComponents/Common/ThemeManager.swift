import SwiftUI
import Auth0UniversalComponents
import Combine

@MainActor
final class ThemeManager: ObservableObject {

    // MARK: - Persistence
    private static let persistenceKey = "auth0_selected_theme"

    // MARK: - Published State
    @Published private(set) var currentTheme: Auth0Theme
    @Published private(set) var activeOption: ThemeOption

    // MARK: - Init
    init() {
        let saved = UserDefaults.standard.string(forKey: Self.persistenceKey)
            .flatMap(ThemeOption.init(rawValue:)) ?? .automatic
        activeOption = saved
        currentTheme = saved.theme
    }

    // MARK: - Apply
    func apply(_ option: ThemeOption) {
        activeOption = option
        currentTheme = option.theme
        UserDefaults.standard.set(option.rawValue, forKey: Self.persistenceKey)
    }
}
