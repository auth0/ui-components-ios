/// A notification message to display temporarily to the user.
///
/// Toast messages appear briefly at the bottom of the screen to provide feedback
/// about operations (success, error, etc.). They automatically dismiss after the
/// specified duration.
struct Toast: Equatable {
    /// The visual style and tone of the toast (success, error, warning, etc.)
    var style: ToastStyle
    /// The message text to display in the toast
    var message: String
    /// How long the toast should be displayed in seconds (defaults to 3 seconds)
    var duration: Double = 3
}
