import SwiftUI

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
