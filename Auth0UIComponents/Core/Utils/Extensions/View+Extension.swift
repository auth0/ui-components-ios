import SwiftUI

extension View {
    /// Attaches a toast notification modifier to the view.
    ///
    /// This convenience method applies the ToastModifier to display toast notifications
    /// on top of the view. Use this to add toast notification capability to any view.
    ///
    /// - Parameter toast: A binding to an optional Toast that controls whether the toast is displayed
    /// - Returns: A modified view with toast capability
    ///
    /// Example:
    /// ```swift
    /// @State var toast: Toast?
    ///
    /// VStack {
    ///   // Your content
    /// }
    /// .toastView(toast: $toast)
    /// ```
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
