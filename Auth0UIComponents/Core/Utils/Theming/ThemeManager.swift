import SwiftUI
import Combine

public class ThemeManager: ObservableObject {
    @Published public var current: Theme
    
    public init(theme: Theme) {
        self.current = theme
    }
}

// The Environment Key
struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = DefaultTheme() // Default starting theme
}

// Extending EnvironmentValues for easy access
public extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
