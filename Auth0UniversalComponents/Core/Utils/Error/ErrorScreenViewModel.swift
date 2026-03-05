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

    /// Initializes the error screen view model.
    ///
    /// - Parameters:
    ///   - title: The error title message
    ///   - subTitle: The detailed error description
    ///   - buttonTitle: The action button text
    ///   - textTap: Callback for message text taps
    ///   - buttonClick: Callback for button clicks
    init(title: String,
         subTitle: AttributedString,
         buttonTitle: String,
         textTap: @escaping () -> Void,
         buttonClick: @escaping () -> Void) {
        self.title = title
        self.subTitle = subTitle
        self.buttonTitle = buttonTitle
        self.buttonClick = buttonClick
        self.textTap = textTap
    }

    /// Handles when the error message text is tapped.
    func handleTextTap() {
        textTap()
    }

    /// Handles when the action button is clicked.
    func handleButtonClick() {
        buttonClick()
    }
}

