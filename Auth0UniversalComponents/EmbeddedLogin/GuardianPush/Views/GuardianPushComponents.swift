import SwiftUI
import Combine

// Building blocks shared by the Guardian push screens. They read only `auth0Theme`, plus `GuardianPushStyle`.

/// Values from the Guardian push Figma frames (393 pt wide) that have no theme token yet.
enum GuardianPushStyle {
    /// Inter Regular 18 pt: screen and outcome titles.
    static var title: Auth0TextStyle { style("Inter-Regular", 18, .title3, lineSpacing: 6) }
    /// Inter Regular 16 pt: the waiting screen's subtitle.
    static var waitingSubtitle: Auth0TextStyle { style("Inter-Regular", 16, .callout, lineSpacing: 3) }
    /// Inter Medium 15 pt: "Choose another device".
    static var action: Auth0TextStyle { style("Inter-Medium", 15, .subheadline, lineSpacing: 0) }

    static let waitingTop: CGFloat = 14
    static let waitingTitleGap: CGFloat = 11
    static let spinnerTop: CGFloat = 96
    static let spinnerDiameter: CGFloat = 44
    static let actionsTop: CGFloat = 59
    static let outcomeMessageTop: CGFloat = 19
    static let rowIconSize: CGFloat = 22
    static let rowLeading: CGFloat = 18

    private static func style(_ name: String, _ size: CGFloat, _ relativeTo: Font.TextStyle,
                              lineSpacing: CGFloat) -> Auth0TextStyle {
        Auth0FontRegistration.registerIfNeeded()
        return Auth0TextStyle(font: .custom(name, size: size, relativeTo: relativeTo), lineSpacing: lineSpacing)
    }
}

/// Title with a wrapping subtitle, as on the second-factor screens.
public struct GuardianPushHeader: View {
    let title: String
    let subtitle: String?
    let subtitleStyle: Auth0TextStyle?
    let spacing: CGFloat?

    @Environment(\.auth0Theme) private var theme

    public init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, subtitleStyle: nil, spacing: nil)
    }

    /// `nil` style and spacing use `typography.bodySmall` and `spacing.sm`.
    init(title: String, subtitle: String?, subtitleStyle: Auth0TextStyle?, spacing: CGFloat?) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleStyle = subtitleStyle
        self.spacing = spacing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing ?? theme.spacing.sm) {
            Text(title)
                .auth0TextStyle(GuardianPushStyle.title)
                .foregroundStyle(theme.colors.text.bold)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .auth0TextStyle(subtitleStyle ?? theme.typography.bodySmall)
                    .foregroundStyle(theme.colors.text.regular)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A tappable Guardian device: icon, name and chevron.
public struct GuardianPushDeviceRow: View {
    let device: GuardianPushDevice
    let action: () -> Void

    @Environment(\.auth0Theme) private var theme

    public init(device: GuardianPushDevice, action: @escaping () -> Void) {
        self.device = device
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.md) {
                Image("totp", bundle: ResourceBundle.default)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: GuardianPushStyle.rowIconSize, height: GuardianPushStyle.rowIconSize)
                    .foregroundStyle(theme.colors.background.primary)
                    .accessibilityHidden(true)
                Text(device.name)
                    .auth0TextStyle(theme.typography.label)
                    .foregroundStyle(theme.colors.text.bold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image("chevron", bundle: ResourceBundle.default)
                    .renderingMode(.template)
                    .foregroundStyle(theme.colors.background.primary)
                    .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
                    .accessibilityHidden(true)
            }
            .padding(.leading, GuardianPushStyle.rowLeading)
            .padding(.trailing, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
            .frame(minHeight: theme.sizes.inputHeight + theme.spacing.xxs)
        }
        .buttonStyle(GuardianPushRowStyle())
        .accessibilityLabel(device.name)
        .accessibilityHint("Sends a sign-in request to this device")
    }
}

/// Resting rows sit on an off-white card; a pressed row lifts to white with a stronger border.
private struct GuardianPushRowStyle: ButtonStyle {
    @Environment(\.auth0Theme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: theme.radius.medium)
        return configuration.label
            .background(isPressed ? theme.colors.background.layerTop : theme.colors.background.layerMedium, in: shape)
            .overlay(shape.strokeBorder(isPressed ? theme.colors.border.bold : theme.colors.border.regular, lineWidth: 1))
            .shadow(color: .black.opacity(isPressed ? 0.08 : 0), radius: 6, x: 0, y: 2)
            .contentShape(shape)
            .animation(.easeOut(duration: 0.12), value: isPressed)
    }
}

/// Centered secondary text action, e.g. "Choose another device".
public struct GuardianPushTextButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.auth0Theme) private var theme

    public init(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .auth0TextStyle(GuardianPushStyle.action)
            .foregroundStyle(theme.colors.text.bold.opacity(isEnabled ? 1 : 0.5))
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .disabled(!isEnabled)
    }
}

/// Filled "Resend Code" button with a cooldown that starts when it appears and after each resend.
struct GuardianPushResendButton: View {
    let cooldown: Int
    let isBusy: Bool
    let onResend: () -> Void

    /// Starts at `cooldown`: a new button (e.g. after a resend) waits again.
    @State private var remaining: Int

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(cooldown: Int = 60, isBusy: Bool = false, onResend: @escaping () -> Void) {
        self.cooldown = cooldown
        self.isBusy = isBusy
        self.onResend = onResend
        _remaining = State(initialValue: cooldown)
    }

    var body: some View {
        Button(remaining > 0 ? "Resend in \(remaining) sec…" : "Resend Code") {
            onResend()
            remaining = cooldown
        }
        .buttonStyle(GuardianPushFilledButtonStyle())
        .disabled(remaining > 0 || isBusy)
        .onReceive(ticker) { _ in if remaining > 0 { remaining -= 1 } }
    }
}

/// `LoginPrimaryButton`'s look, except that disabled fades only the fill: the label stays `text.onPrimary`.
private struct GuardianPushFilledButtonStyle: ButtonStyle {
    @Environment(\.auth0Theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.inputField, style: .continuous)
        return configuration.label
            .auth0TextStyle(theme.typography.label)
            .foregroundStyle(theme.colors.text.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background {
                shape.fill(theme.colors.background.primary)
                    .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.04)],
                                                       startPoint: .top, endPoint: .bottom)))
                    .overlay(shape.strokeBorder(theme.colors.background.primary, lineWidth: 1))
                    // The design's greyed-out fill.
                    .opacity(isEnabled ? 1 : 0.45)
            }
            .shadow(color: .black.opacity(isEnabled ? 0.12 : 0), radius: 4, x: 0, y: 2)
            .contentShape(shape)
    }
}

/// Centered title and message with an optional action, for terminal and transient outcomes. No icon.
struct GuardianPushStatusLayout<Action: View>: View {
    let title: String
    let message: String
    @ViewBuilder let action: () -> Action

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .auth0TextStyle(GuardianPushStyle.title)
                .foregroundStyle(theme.colors.text.bold)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .auth0TextStyle(theme.typography.helper)
                .foregroundStyle(theme.colors.text.regular)
                .padding(.top, GuardianPushStyle.outcomeMessageTop)
            action()
                .padding(.top, theme.spacing.md)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, theme.spacing.xl)
        // Sits slightly above center, as in the design.
        .padding(.bottom, theme.spacing.xl)
    }
}
