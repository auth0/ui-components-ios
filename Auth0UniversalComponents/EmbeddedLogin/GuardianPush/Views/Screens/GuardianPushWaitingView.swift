import SwiftUI

/// The push is on its way or waiting for approval in Guardian.
public struct GuardianPushWaitingView: View {
    let deviceName: String
    let isSending: Bool
    /// `nil` hides the resend row.
    let onResend: (() -> Void)?
    /// `nil` hides "Choose another device".
    let onChooseAnotherDevice: (() -> Void)?

    @Environment(\.auth0Theme) private var theme

    public init(deviceName: String,
                isSending: Bool = false,
                onResend: (() -> Void)? = nil,
                onChooseAnotherDevice: (() -> Void)? = nil) {
        self.deviceName = deviceName
        self.isSending = isSending
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
                        GuardianPushResendButton(isBusy: isSending, onResend: onResend)
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
