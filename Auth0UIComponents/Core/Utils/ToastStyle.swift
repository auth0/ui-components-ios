import SwiftUI

/// Defines the semantic intent of a toast notification.
///
/// The visual representation of each case — colours and backgrounds — is
/// resolved against the active ``Auth0Theme`` at render time, so it
/// automatically reflects any custom theme injected via
/// ``SwiftUI/View/auth0Theme(_:)``.
enum ToastStyle {
    /// Critical error — rendered in red.
    case error
    /// Non-critical warning — rendered in orange.
    case warning
    /// Positive confirmation — rendered in green.
    case success
    /// Neutral information — rendered in blue.
    case info
    /// SDK notification (e.g. "Copied") — rendered using the theme's primary colour.
    case notify
}

extension ToastStyle {

    /// Returns the accent colour for this style, sourced from `theme` for
    /// semantic cases and from system colours for warning/info.
    func themeColor(from theme: Auth0Theme) -> Color {
        switch self {
        case .error:   return theme.colors.text.onError
        case .warning: return .orange
        case .info:    return .blue
        case .success: return theme.colors.text.onSuccess
        case .notify:  return theme.colors.background.primary
        }
    }

    /// Returns the message text colour appropriate for the toast background.
    func messageColor(from theme: Auth0Theme) -> Color {
        switch self {
        case .error:   return theme.colors.text.onError
        case .success: return theme.colors.text.onSuccess
        case .notify:  return theme.colors.text.onPrimary
        default:       return theme.colors.text.bold
        }
    }

    /// Returns the background colour of the toast container.
    func toastBackgroundColor(from theme: Auth0Theme) -> Color {
        switch self {
        case .error:   return theme.colors.background.errorSubtle
        case .success: return theme.colors.background.successSubtle
        case .notify:  return theme.colors.background.primary
        default:       return theme.colors.text.onPrimary
        }
    }
}
