import Foundation

/// Waiting for the user to approve a push.
public struct PushChallengeModel: MfaFactorModel, Equatable {
    /// The name of the device the request was sent to. Empty when the server sent no name: the standard screen then
    /// uses ``PushChallengeMessages/descriptionUnnamed``, and a custom screen should not print an empty name.
    public let deviceName: String
    /// Whether the server allows the request to be sent again.
    public let canResend: Bool
    /// Seconds until resend is allowed; 0 when it can be used now. ``canResend`` still says whether the server allows
    /// it at all.
    ///
    /// The flow owns this countdown, so every screen, standard or custom, gets the same wait: calling ``resend`` before
    /// it reaches 0 does nothing. The model is published again each second while it counts down. Show it with
    /// `messages.pushChallenge.resend.cooldown(model.resendAvailableIn)`.
    public let resendAvailableIn: Int
    /// Whether there is another factor to switch to.
    public let canSwitch: Bool
    /// Sends the request again.
    public let resend: MfaAction<Void>
    /// Goes back to the factor list.
    public let switchFactor: MfaAction<Void>
    /// Ends the flow as cancelled.
    public let cancel: MfaAction<Void>

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - deviceName: The name of the device the request was sent to.
    ///   - canResend: Whether the server allows the request to be sent again.
    ///   - resendAvailableIn: Seconds until resend is allowed; 0 when it can be used now.
    ///   - canSwitch: Whether there is another factor to switch to.
    ///   - resend: Sends the request again.
    ///   - switchFactor: Goes back to the factor list.
    ///   - cancel: Ends the flow.
    public init(deviceName: String, canResend: Bool = false, resendAvailableIn: Int = 0, canSwitch: Bool = false,
                resend: MfaAction<Void> = .none, switchFactor: MfaAction<Void> = .none,
                cancel: MfaAction<Void> = .none) {
        self.deviceName = deviceName
        self.canResend = canResend
        self.resendAvailableIn = resendAvailableIn
        self.canSwitch = canSwitch
        self.resend = resend
        self.switchFactor = switchFactor
        self.cancel = cancel
    }
}

extension MfaFactorID {
    /// Approve a sign-in request on a registered device.
    public static let push: MfaFactorID = "push"
}

extension MfaScreens {
    /// The same call shape as the Core's own slots: `MfaScreens(pushChallenge: .custom { model in … })`.
    public init(authenticatorList: MfaScreenSlot<AuthenticatorListModel> = .standard,
                pushChallenge: MfaScreenSlot<PushChallengeModel>,
                error: MfaScreenSlot<ErrorModel> = .standard) {
        self.init(authenticatorList: authenticatorList, error: error)
        if case let .custom(build) = pushChallenge.source { self = replacing(.push, with: build) }
    }
}
