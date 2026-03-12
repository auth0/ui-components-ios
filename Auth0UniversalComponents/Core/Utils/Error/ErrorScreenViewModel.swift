import Foundation

/// View model for displaying error states in the UI.
///
/// Encapsulates all data and callbacks needed to display an error screen,
/// including the error title, detailed message, button text, and event handlers.
struct ErrorScreenViewModel {
    /// The title of the error message
    let title: String
    /// The detailed error description as an attributed string
    let subTitle: AttributedString
    /// Callback invoked when the user taps on the message text
    let textTap: () -> Void
    /// The title text for the action button
    let buttonTitle: String
    /// Callback invoked when the user taps the action button
    let buttonClick: () -> Void
    /// Optional callback invoked when the user taps the dismiss (×) button.
    ///
    /// When non-`nil`, `ErrorScreen` renders a close button in the top-trailing
    /// corner. Use this when the error screen is presented modally and the user
    /// must be able to dismiss it without retrying.
    let onDismiss: (() -> Void)?

    /// Initializes the error screen view model.
    ///
    /// - Parameters:
    ///   - title: The error title message
    ///   - subTitle: The detailed error description
    ///   - buttonTitle: The action button text
    ///   - textTap: Callback for message text taps
    ///   - buttonClick: Callback for button clicks
    ///   - onDismiss: Optional callback shown as a close button; pass `nil` (default) to hide it
    init(title: String,
         subTitle: AttributedString,
         buttonTitle: String,
         textTap: @escaping () -> Void,
         buttonClick: @escaping () -> Void,
         onDismiss: (() -> Void)? = nil) {
        self.title = title
        self.subTitle = subTitle
        self.buttonTitle = buttonTitle
        self.buttonClick = buttonClick
        self.textTap = textTap
        self.onDismiss = onDismiss
    }

    /// Handles when the error message text is tapped.
    func handleTextTap() {
        textTap()
    }

    /// Handles when the action button is clicked.
    func handleButtonClick() {
        buttonClick()
    }

    /// Handles when the dismiss button is tapped.
    func handleDismiss() {
        onDismiss?()
    }

    /// Returns a copy of this view model with a dismiss callback attached.
    ///
    /// Use this at modal presentation sites to add close-button behaviour
    /// without changing how the originating view model constructs the error.
    ///
    /// ```swift
    /// ErrorScreen(viewModel: errorVM.dismissable { viewModel.errorViewModel = nil })
    /// ```
    func dismissable(onDismiss: @escaping () -> Void) -> ErrorScreenViewModel {
        ErrorScreenViewModel(
            title: title,
            subTitle: subTitle,
            buttonTitle: buttonTitle,
            textTap: textTap,
            buttonClick: buttonClick,
            onDismiss: onDismiss
        )
    }
}
