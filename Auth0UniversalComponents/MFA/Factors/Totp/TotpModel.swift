import Foundation

/// Waiting for the code from the user's authenticator app.
public struct TotpChallengeModel: MfaFactorModel, Equatable {
    /// How many digits the code has.
    public let codeLength: Int
    /// A code was submitted and is being checked: show progress, and don't take another.
    public let isVerifying: Bool
    /// The last code was wrong. Show `messages.totpChallenge.invalidCode`. Cleared when another code is submitted.
    public let isCodeRejected: Bool
    /// `.network` when the connection dropped while the code was being checked: the screen stays and the code can be
    /// typed again. `nil` otherwise; cleared when the next check starts. Show `messages.totpChallenge.noConnection`.
    public let requestError: MfaError?
    /// Whether there is another factor to switch to.
    public let canSwitch: Bool
    /// Checks a code. Pass all ``codeLength`` digits; anything else is ignored.
    public let submit: MfaAction<String>
    /// Goes back to the factor list.
    public let switchFactor: MfaAction<Void>
    /// Ends the flow as cancelled.
    public let cancel: MfaAction<Void>

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - codeLength: How many digits the code has.
    ///   - isVerifying: Whether a submitted code is being checked.
    ///   - isCodeRejected: Whether the last code was wrong.
    ///   - requestError: Why the last check failed, when the screen stays up.
    ///   - canSwitch: Whether there is another factor to switch to.
    ///   - submit: Checks a code.
    ///   - switchFactor: Goes back to the factor list.
    ///   - cancel: Ends the flow.
    public init(codeLength: Int = 6, isVerifying: Bool = false, isCodeRejected: Bool = false,
                requestError: MfaError? = nil, canSwitch: Bool = false,
                submit: MfaAction<String> = .init { _ in }, switchFactor: MfaAction<Void> = .none,
                cancel: MfaAction<Void> = .none) {
        self.codeLength = codeLength
        self.isVerifying = isVerifying
        self.isCodeRejected = isCodeRejected
        self.requestError = requestError
        self.canSwitch = canSwitch
        self.submit = submit
        self.switchFactor = switchFactor
        self.cancel = cancel
    }
}

extension MfaFactorID {
    /// Enter the code an authenticator app shows.
    public static let totp: MfaFactorID = "totp"
}

extension MfaScreens {
    /// The same call shape as the Core's own slots: `MfaScreens(totpChallenge: .custom { model in … })`.
    public init(authenticatorList: MfaScreenSlot<AuthenticatorListModel> = .standard,
                totpChallenge: MfaScreenSlot<TotpChallengeModel>,
                error: MfaScreenSlot<ErrorModel> = .standard) {
        self.init(authenticatorList: authenticatorList, error: error)
        if case let .custom(build) = totpChallenge.source { self = replacing(.totp, with: build) }
    }
}
