import SwiftUI

enum ToastStyle {
  case error
  case warning
  case success
  case info
  case notify
}

extension ToastStyle {
    var themeColor: Color {
        switch self {
        case .error: return Color.red
        case .warning: return Color.orange
        case .info: return Color.blue
        case .success: return Color.green
        case .notify: return Color("262420", bundle: ResourceBundle.default)
        }
    }

    var messageColor: Color {
        switch self {
        case .notify:
            return Color("FFFFFF", bundle: ResourceBundle.default)
        default:
            return Color("000000", bundle: ResourceBundle.default)
        }
    }

    var toastBackgroundColor: Color {
        switch self {
        case .notify:
            return Color("262420", bundle: ResourceBundle.default)
        default:
            return Color("FFFFFF", bundle: ResourceBundle.default)
        }
    }
}
