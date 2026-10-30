import SwiftUI

/// Why the flow ended, in plain words, with "Start over" in login or "Close" in a step-up sheet.
public struct MfaErrorScreen: View {
    let model: ErrorModel
    let messages: MfaMessages

    /// Creates the screen.
    ///
    /// - Parameters:
    ///   - model: What the screen renders and the actions it calls.
    ///   - messages: The words to use.
    public init(model: ErrorModel, messages: MfaMessages = .default) {
        self.model = model
        self.messages = messages
    }

    /// The screen.
    public var body: some View {
        let copy = messages.errors.message(for: model.error)
        MfaStatusLayout(title: copy.title, message: copy.description) {
            MfaPrimaryButton(model.exit == .close ? messages.errors.close : messages.errors.startOver) {
                model.leave()
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Denied") {
    MfaErrorScreen(model: ErrorModel(error: .rejected))
}

#Preview("Expired, step-up") {
    MfaErrorScreen(model: ErrorModel(error: .tokenExpired, exit: .close))
}

#Preview("No connection") {
    MfaErrorScreen(model: ErrorModel(error: .network))
}
