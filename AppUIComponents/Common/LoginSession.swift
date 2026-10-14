import Foundation

/// How the current session was signed in, so logout can pick the right teardown.
enum LoginMethod: String {
    case universal
    case embedded
}

/// `UserDefaults`-backed record of the last login method.
enum LoginSession {
    private static let key = "com.auth0.uicomponents.lastLoginMethod"

    /// `nil` (unknown) is treated as Universal at logout.
    static var method: LoginMethod? {
        get { UserDefaults.standard.string(forKey: key).flatMap(LoginMethod.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: key) }
    }

    static func record(_ method: LoginMethod) {
        self.method = method
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
