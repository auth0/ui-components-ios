import SwiftUI

/// More than the email code is required, but no factor this app can run is available (e.g. only SMS), or none is
/// enrolled.
public struct LoginAdditionalStepUnavailableScreen: View {
    let onSignInAgain: () -> Void

    public init(onSignInAgain: @escaping () -> Void) {
        self.onSignInAgain = onSignInAgain
    }

    public var body: some View {
        StatusLayout(
            title: "Verification method not available.",
            message: "Your account doesn't have a verification method this app can use. "
                + "Contact your administrator for help."
        ) {
            LoginPrimaryButton("Sign in again", action: onSignInAgain)
        }
    }
}

#Preview("Additional step unavailable") {
    LoginAdditionalStepUnavailableScreen {}
}
