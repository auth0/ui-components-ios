import SwiftUI

// Guardian push screens. Each is plug-and-play: plain values in, closures out, no controller.

/// Lists the user's Guardian devices.
public struct GuardianPushDevicePickerView: View {
    let devices: [GuardianPushDevice]
    let onSelect: (GuardianPushDevice) -> Void

    @Environment(\.auth0Theme) private var theme

    public init(devices: [GuardianPushDevice], onSelect: @escaping (GuardianPushDevice) -> Void) {
        self.devices = devices
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GuardianPushHeader(title: "Choose a device",
                               subtitle: "Where should we send the sign-in request?")
            VStack(spacing: theme.spacing.xs) {
                ForEach(devices) { device in
                    GuardianPushDeviceRow(device: device) { onSelect(device) }
                }
            }
            .padding(.top, theme.spacing.lg)
            Spacer()
        }
        .embeddedScreenChrome(theme: theme, horizontalPadding: theme.spacing.xl,
                              topPadding: theme.spacing.lg + theme.spacing.xxs)
    }
}

/// The push is on its way or waiting for approval in Guardian.
public struct GuardianPushWaitingView: View {
    let deviceName: String
    let isSending: Bool
    /// `nil` hides the resend row.
    let onResend: (() -> Void)?
    /// `nil` hides "Choose another device".
    let onChooseAnotherDevice: (() -> Void)?
    /// Seconds before Resend is enabled.
    let resendCooldown: Int

    @Environment(\.auth0Theme) private var theme

    public init(deviceName: String,
                isSending: Bool = false,
                onResend: (() -> Void)? = nil,
                onChooseAnotherDevice: (() -> Void)? = nil) {
        self.init(deviceName: deviceName, isSending: isSending, resendCooldown: 60,
                  onResend: onResend, onChooseAnotherDevice: onChooseAnotherDevice)
    }

    init(deviceName: String, isSending: Bool, resendCooldown: Int,
         onResend: (() -> Void)?, onChooseAnotherDevice: (() -> Void)?) {
        self.deviceName = deviceName
        self.isSending = isSending
        self.resendCooldown = resendCooldown
        self.onResend = onResend
        self.onChooseAnotherDevice = onChooseAnotherDevice
    }

    private var status: String { isSending ? "Sending request" : "Waiting for approval" }

    private var subtitle: String {
        isSending
            ? "Sending a sign-in request to \(deviceName)."
            : "We sent a sign-in request to \(deviceName). Approve it in the Guardian app to continue."
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GuardianPushHeader(title: "Check your device", subtitle: subtitle,
                               subtitleStyle: GuardianPushStyle.waitingSubtitle,
                               spacing: GuardianPushStyle.waitingTitleGap)

            VStack(spacing: theme.spacing.sm) {
                BrandSpinner(diameter: GuardianPushStyle.spinnerDiameter)
                Text(status)
                    .auth0TextStyle(theme.typography.bodySmall)
                    .foregroundStyle(theme.colors.text.regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, GuardianPushStyle.spinnerTop)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(status) on \(deviceName)")

            if onResend != nil || onChooseAnotherDevice != nil {
                VStack(spacing: theme.spacing.md) {
                    if let onResend {
                        GuardianPushResendButton(cooldown: resendCooldown, isBusy: isSending, onResend: onResend)
                    }
                    if let onChooseAnotherDevice {
                        GuardianPushTextButton("Choose another device", isEnabled: !isSending,
                                               action: onChooseAnotherDevice)
                    }
                }
                .padding(.top, GuardianPushStyle.actionsTop)
            }

            Spacer()
        }
        .embeddedScreenChrome(theme: theme, horizontalPadding: theme.spacing.xl,
                              topPadding: GuardianPushStyle.waitingTop)
    }
}

/// A terminal or retryable outcome: title, message and one action, with no icon.
public struct GuardianPushOutcomeView: View {
    let failure: GuardianPushFailure
    /// Retryable failures only (`failure.isRetryable`).
    let onRetry: (() -> Void)?
    /// Starts a new sign-in. `nil` hides the button.
    let onSignInAgain: (() -> Void)?

    public init(failure: GuardianPushFailure, onRetry: (() -> Void)? = nil, onSignInAgain: (() -> Void)? = nil) {
        self.failure = failure
        self.onRetry = onRetry
        self.onSignInAgain = onSignInAgain
    }

    public var body: some View {
        let content = GuardianPushOutcomeContent(failure)
        GuardianPushStatusLayout(title: content.title, message: content.message) {
            if failure.isRetryable, let onRetry {
                LoginPrimaryButton("Try again", action: onRetry)
            } else if let onSignInAgain {
                LoginPrimaryButton("Sign in again", action: onSignInAgain)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Copy for each outcome.
struct GuardianPushOutcomeContent: Equatable {
    let title: String
    let message: String

    init(_ failure: GuardianPushFailure) {
        switch failure {
        case .unavailable:
            self.init(title: "Push notification isn't available.",
                      message: "This account doesn't have a Guardian device that can approve this sign-in.")
        case .denied:
            self.init(title: "Sign-in request denied.",
                      message: "The request was denied in Guardian. If you didn't try to sign in, change your password.")
        case .expired:
            self.init(title: "Request expired.",
                      message: "The request wasn't approved in time. Sign in again to send a new one.")
        case .sessionEnded:
            self.init(title: "Sign-in session ended.",
                      message: "Your sign-in session ended. Please sign in again.")
        case .network:
            self.init(title: "No connection.",
                      message: "Check your connection and try again.")
        case let .other(message):
            self.init(title: "Sign in couldn't be completed.",
                      message: message ?? "We are unable to process your request. Please try again in a few minutes.")
        }
    }

    private init(title: String, message: String) {
        self.title = title
        self.message = message
    }
}

/// Shown briefly once Guardian approves.
public struct GuardianPushApprovedView: View {
    public init() {}

    public var body: some View {
        GuardianPushStatusLayout(title: "Approved.", message: "Finishing sign-in…") { EmptyView() }
    }
}
