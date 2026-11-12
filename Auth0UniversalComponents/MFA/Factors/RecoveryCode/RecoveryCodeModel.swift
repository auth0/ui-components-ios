import Foundation

/// Typing a recovery code, and then saving the new one the server issues in its place.
public struct RecoveryCodeChallengeModel: MfaFactorModel, Equatable {
    /// The code that replaces the one just used, once the server accepted it. `nil` while the user is still typing:
    /// show the field. Otherwise show this code so they can save it, and call ``confirm`` when they have.
    public let newCode: String?
    /// A request is in flight: show progress, and don't take another.
    public let isVerifying: Bool
    /// The last code was wrong. Show `messages.recoveryCodeChallenge.invalidCode`. Cleared when another is submitted.
    public let isCodeRejected: Bool
    /// `.network` when the connection dropped: nothing was lost, so submit or confirm again. Cleared when the next
    /// request starts.
    public let requestError: MfaError?
    /// Whether there is another factor to switch to.
    public let canSwitch: Bool
    /// Checks the code. Spaces around it are ignored; an empty code is ignored.
    public let submit: MfaAction<String>
    /// The user has saved ``newCode``: finishes the sign-in.
    public let confirm: MfaAction<Void>
    /// Goes back to the factor list.
    public let switchFactor: MfaAction<Void>
    /// Ends the flow as cancelled.
    public let cancel: MfaAction<Void>

    /// Creates a model.
    public init(newCode: String? = nil, isVerifying: Bool = false, isCodeRejected: Bool = false,
                requestError: MfaError? = nil, canSwitch: Bool = false,
                submit: MfaAction<String> = .init { _ in }, confirm: MfaAction<Void> = .none,
                switchFactor: MfaAction<Void> = .none, cancel: MfaAction<Void> = .none) {
        self.newCode = newCode
        self.isVerifying = isVerifying
        self.isCodeRejected = isCodeRejected
        self.requestError = requestError
        self.canSwitch = canSwitch
        self.submit = submit
        self.confirm = confirm
        self.switchFactor = switchFactor
        self.cancel = cancel
    }
}

extension MfaFactorID {
    /// Enter one of the user's recovery codes.
    public static let recoveryCode: MfaFactorID = "recovery_code"
}
