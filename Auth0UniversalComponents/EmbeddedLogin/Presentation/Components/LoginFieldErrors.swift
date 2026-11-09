import Foundation

/// What an entry form shows under its field: its own format check first, then the server's error. The server's error
/// hides once the user edits, and comes back when the server reports again.
struct LoginFieldErrors: Equatable {
    /// The form's own check failed, e.g. "Please enter a valid email address."
    var validation: String?
    private var isServerErrorHidden = false

    func shown(server: String?) -> String? {
        validation ?? (isServerErrorHidden ? nil : server)
    }

    mutating func userEdited() {
        validation = nil
        isServerErrorHidden = true
    }

    mutating func serverReported() {
        isServerErrorHidden = false
    }
}
