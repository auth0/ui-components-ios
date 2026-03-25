import SwiftUI
import Combine
import Auth0UniversalComponents

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Properties
    @Published var sections: [ProfileSection] = []
    private let profile: ProfileModel
    private var isAttached = false
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Static Formatters
    // Shared instances avoid re-allocation on every call. POSIX locale locks month names to
    // English to match the hardcoded ordinal suffixes ("st", "nd", "rd", "th").
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "H:mm:ss"
        return formatter
    }()

    // MARK: - Init
    init(profile: ProfileModel) {
        self.profile = profile
        // Populate sections before the first render so the view is never empty.
        buildSections(for: .automatic)
    }

    // MARK: - Attach
    // Called once by the View. Rebuilds with the real active theme, then subscribes to
    // future changes via Combine so the ViewModel drives all updates independently.
    func attach(to themeManager: ThemeManager) {
        guard !isAttached else { return }
        isAttached = true

        buildSections(for: themeManager.activeOption)

        themeManager.$activeOption
            .dropFirst()
            .sink { [weak self] option in
                self?.buildSections(for: option)
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties
    var displayName: String {
        combinedName.isEmpty ? profile.name : combinedName
    }

    private var combinedName: String {
        [profile.givenName, profile.familyName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var lastUpdatedText: String {
        guard let date = profile.lastUpdatedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last updated \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    // MARK: - Build Sections

    private func buildSections(for option: ThemeOption) {
        let name = displayName
        let email = profile.email
        let dateStr = formattedDate(profile.lastUpdatedAt)

        var generalRows: [ProfileOptionRow] = []

        if name.isNotEmpty {
            generalRows.append(ProfileOptionRow(id: "general.name", icon: "person", title: name, detail: nil, route: nil))
        }

        if let email {
            generalRows.append(ProfileOptionRow(id: "general.email", icon: "envelope", title: email, detail: nil, route: nil))
        }

        if !dateStr.isEmpty {
            generalRows.append(ProfileOptionRow(id: "general.date", icon: "clock.arrow.circlepath", title: dateStr, detail: nil, route: nil))
        }

        sections = [
            ProfileSection(
                id: "general",
                title: "General",
                description: "Update your personal information",
                rows: generalRows
            ),
            ProfileSection(
                id: "app-setting",
                title: "App Setting",
                description: nil,
                rows: [
                    ProfileOptionRow(id: "setting.theme", icon: nil, title: "Theme", detail: option.title, route: .appearance)
                ]
            )
        ]
    }

    // MARK: - Helpers
    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)

        let suffix: String
        switch day {
        case 11, 12, 13: suffix = "th"
        case let day where day % 10 == 1: suffix = "st"
        case let day where day % 10 == 2: suffix = "nd"
        case let day where day % 10 == 3: suffix = "rd"
        default: suffix = "th"
        }

        let month = Self.monthFormatter.string(from: date)
        let year = Self.yearFormatter.string(from: date)
        let time = Self.timeFormatter.string(from: date)

        return "\(month) \(day)\(suffix) \(year), \(time)"
    }
}
