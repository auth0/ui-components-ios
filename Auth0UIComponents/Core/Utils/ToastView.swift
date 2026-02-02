import SwiftUI

/// Displays a toast notification message with styled appearance.
///
/// Renders the toast message text with colors and styling determined by the ToastStyle.
/// This view handles the visual presentation of toast notifications.
struct ToastView: View {
    /// The visual style of the toast (error, warning, success, etc.)
    var style: ToastStyle
    /// The message text to display
    var message: String
    /// Callback invoked when the user cancels/dismisses the toast
    var onCancelTapped: (() -> Void)

    var body: some View {
        Text(message)
            .font(Font.caption)
            .foregroundColor(style.messageColor)
            .padding()
            .background(style.toastBackgroundColor)
            .cornerRadius(8)
            .padding(.horizontal, 16)
    }
}
