import SwiftUI

/// Defines the visual style and semantic meaning of a toast notification.
///
/// Each style determines the colors used for the toast background and text,
/// conveying different types of messages to the user.
enum ToastStyle {
    /// Error messages - displayed in red
    case error
    /// Warning messages - displayed in orange
    case warning
    /// Success messages - displayed in green
    case success
    /// Informational messages - displayed in blue
    case info
    /// Neutral notification messages - displayed with dark background and white text
    case notify
}

extension ToastStyle {
    /// The theme color for this toast style
    var themeColor: Color {
        switch self {
        case .error: return Color.red
        case .warning: return Color.orange
        case .info: return Color.blue
        case .success: return Color.green
        case .notify: return Color("262420", bundle: ResourceBundle.default)
        }
    }

    /// The color to use for the toast message text
    var messageColor: Color {
        switch self {
        case .notify:
            return Color("FFFFFF", bundle: ResourceBundle.default)
        default:
            return Color("000000", bundle: ResourceBundle.default)
        }
    }

    /// The background color for the toast container
    var toastBackgroundColor: Color {
        switch self {
        case .notify:
            return Color("262420", bundle: ResourceBundle.default)
        default:
            return Color("FFFFFF", bundle: ResourceBundle.default)
        }
    }
}
