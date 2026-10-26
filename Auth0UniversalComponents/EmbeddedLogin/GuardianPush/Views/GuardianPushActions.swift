import SwiftUI

/// What the Guardian push screens can ask for. A `nil` closure hides its button.
public struct GuardianPushActions {
    /// A device was picked from the list.
    public var selectDevice: (GuardianPushDevice) -> Void
    /// Sends the push again; shown only when the state allows it.
    public var resend: (() -> Void)?
    /// Retries after a retryable failure (`.network`).
    public var retry: (() -> Void)?
    /// Back to the device list.
    public var chooseAnotherDevice: (() -> Void)?
    /// Terminal outcomes: start a new sign-in.
    public var signInAgain: (() -> Void)?

    public init(selectDevice: @escaping (GuardianPushDevice) -> Void,
                resend: (() -> Void)? = nil,
                retry: (() -> Void)? = nil,
                chooseAnotherDevice: (() -> Void)? = nil,
                signInAgain: (() -> Void)? = nil) {
        self.selectDevice = selectDevice
        self.resend = resend
        self.retry = retry
        self.chooseAnotherDevice = chooseAnotherDevice
        self.signInAgain = signInAgain
    }
}
