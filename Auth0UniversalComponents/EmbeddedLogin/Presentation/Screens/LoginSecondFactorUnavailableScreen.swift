import SwiftUI

/// A second factor is required, but none this app can run is on offer (e.g. only SMS), or the user has none.
public struct LoginSecondFactorUnavailableScreen: View {
    let onSignInAgain: () -> Void

    public init(onSignInAgain: @escaping () -> Void) {
        self.onSignInAgain = onSignInAgain
    }

    public var body: some View {
        GuardianPushStatusLayout(
            title: "Verification method not available.",
            message: "Your account doesn't have a verification method this app can use. "
                + "Contact your administrator for help."
        ) {
            LoginPrimaryButton("Sign in again", action: onSignInAgain)
        }
    }
}

#Preview("Second factor unavailable") {
    LoginSecondFactorUnavailableScreen {}
}
