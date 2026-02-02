import SwiftUI

extension View {

  func toastView(toast: Binding<Toast?>) -> some View {
    self.modifier(ToastModifier(toast: toast))
  }
}

public extension View {
    /// Convenience modifier for the host app to inject their brand.
    func setTheme(_ theme: Theme) -> some View {
        self.environment(\.appTheme, theme)
    }
}

// MARK: - Extension for Text Custom Theme Style
public extension View {
    /// Applies the  SDK theme to any text-based view.
    /// - Parameters:
    ///   - role: The semantic role (heading, body, caption).
    ///   - theme: An optional explicit theme override.
    func textStyle(_ role: TextRole, theme: (any Theme)? = nil) -> some View {
        self.modifier(TextModifier(role: role, customTheme: theme))
    }
}

// MARK: - Extension for Button Custom Theme Style
public extension View {
    func themeButtonStyle(_ variant: ThemeButtonVariant = .primary, theme: (any Theme)? = nil) -> some View {
        self.buttonStyle(AppThemeButtonStyle(variant: variant, customTheme: theme))
    }
}
