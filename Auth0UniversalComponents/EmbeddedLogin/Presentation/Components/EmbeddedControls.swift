import Combine
import SwiftUI

// Standalone building blocks for the Embedded Login screens; they read only `auth0Theme`.

/// Top bar with a back arrow and a centered title.
public struct LoginNavigationBar: View {
    let title: String
    let isBackEnabled: Bool
    let onBack: (() -> Void)?

    @Environment(\.auth0Theme) private var theme

    public init(title: String = "Log in", isBackEnabled: Bool = true, onBack: (() -> Void)? = nil) {
        self.title = title
        self.isBackEnabled = isBackEnabled
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            Text(title)
                .auth0TextStyle(theme.typography.title)
                .foregroundStyle(theme.colors.text.bold)
            if let onBack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(theme.colors.text.bold)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isBackEnabled)
                    .opacity(isBackEnabled ? 1 : 0.4)
                    .accessibilityLabel("Back")
                    Spacer()
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, theme.spacing.xs)
    }
}

/// Screen title with an optional subtitle and "Edit" action.
public struct LoginScreenHeader: View {
    let title: String
    let subtitle: String?
    let isEditEnabled: Bool
    let onEdit: (() -> Void)?

    @Environment(\.auth0Theme) private var theme

    public init(title: String, subtitle: String? = nil, isEditEnabled: Bool = true, onEdit: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.isEditEnabled = isEditEnabled
        self.onEdit = onEdit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(title)
                .auth0TextStyle(theme.typography.body)
                .foregroundStyle(theme.colors.text.bold)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                HStack(spacing: theme.spacing.sm) {
                    Text(subtitle)
                        .auth0TextStyle(theme.typography.body)
                        .foregroundStyle(theme.colors.text.regular)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let onEdit {
                        Button("Edit", action: onEdit)
                            .buttonStyle(.plain)
                            .auth0TextStyle(theme.typography.title)
                            .foregroundStyle(theme.colors.text.bold)
                            .disabled(!isEditEnabled)
                            .opacity(isEditEnabled ? 1 : 0.4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, subtitle == nil ? 36 : theme.spacing.xxxl)
    }
}

/// Label above a field.
public struct LoginFieldLabel: View {
    let text: String
    @Environment(\.auth0Theme) private var theme

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .auth0TextStyle(theme.typography.label)
            .foregroundStyle(theme.colors.text.bold)
            .padding(.bottom, theme.spacing.md)
    }
}

/// Rounded input container. `isInvalid` switches to the error treatment (pink fill, red text).
public struct LoginInputField<Content: View, Trailing: View>: View {
    let isInvalid: Bool
    let content: () -> Content
    let trailing: () -> Trailing

    @Environment(\.auth0Theme) private var theme

    public init(isInvalid: Bool = false,
                @ViewBuilder content: @escaping () -> Content,
                @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.isInvalid = isInvalid
        self.content = content
        self.trailing = trailing
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.inputField, style: .continuous)
        HStack(spacing: theme.spacing.sm) {
            content()
                .auth0TextStyle(theme.typography.label)
                .foregroundStyle(isInvalid ? theme.colors.loginError : theme.colors.text.bold)
                .tint(isInvalid ? theme.colors.loginError : theme.colors.background.primary)
            trailing()
        }
        .padding(.horizontal, theme.spacing.md)
        .frame(height: theme.sizes.size3xlDimen)
        .background(isInvalid ? theme.colors.background.errorSubtle : theme.colors.background.layerTop, in: shape)
        .overlay(shape.strokeBorder(isInvalid ? theme.colors.errorBorder : theme.colors.border.subtle, lineWidth: 1))
        .errorRing(isInvalid, cornerRadius: theme.radius.inputField, color: theme.colors.errorRing)
        .shadow(color: .black.opacity(isInvalid ? 0 : 0.05), radius: 6, x: 0, y: 2)
    }
}

/// Red helper text beneath a field.
public struct LoginInlineError: View {
    let message: String
    @Environment(\.auth0Theme) private var theme

    public init(_ message: String) { self.message = message }

    public var body: some View {
        Text(message)
            .auth0TextStyle(theme.typography.bodySmall)
            .foregroundStyle(theme.colors.loginError)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Full-width primary button with an in-place loader.
public struct LoginPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    @Environment(\.auth0Theme) private var theme

    public init(_ title: String, isLoading: Bool = false, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.inputField, style: .continuous)
        Button(action: { if !isLoading { action() } }) {
            ZStack {
                if isLoading {
                    Auth0Loader(tintColor: theme.colors.text.onPrimary)
                } else {
                    Text(title)
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.text.onPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(fill, in: shape)
            .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0.04)],
                                               startPoint: .top, endPoint: .bottom)))
            .overlay(shape.strokeBorder(theme.colors.background.primary.opacity(isLoading ? 0 : 1), lineWidth: 1))
            .shadow(color: .black.opacity(isEnabled && !isLoading ? 0.12 : 0), radius: 4, x: 0, y: 2)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled || isLoading ? 1 : 0.5)
    }

    private var fill: Color {
        isLoading ? theme.colors.background.primary.opacity(0.7) : theme.colors.background.primary
    }
}

/// "Resend Code" with a cooldown that starts on appear and after each resend.
public struct LoginResendButton: View {
    let cooldown: Int
    /// Disables the row while a verify is in flight.
    let isBusy: Bool
    let onResend: () -> Void

    @Environment(\.auth0Theme) private var theme
    @State private var remaining = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(cooldown: Int = 60, isBusy: Bool = false, onResend: @escaping () -> Void) {
        self.cooldown = cooldown
        self.isBusy = isBusy
        self.onResend = onResend
    }

    private var isCoolingDown: Bool { remaining > 0 }

    public var body: some View {
        Button(isCoolingDown ? "Resend in \(remaining) sec…" : "Resend Code") {
            onResend()
            remaining = cooldown
        }
        .buttonStyle(.plain)
        .auth0TextStyle(theme.typography.body)
        .foregroundStyle(theme.colors.text.regular.opacity(isCoolingDown || isBusy ? 0.7 : 1))
        .frame(maxWidth: .infinity)
        .disabled(isCoolingDown || isBusy)
        .onAppear { if remaining == 0 { remaining = cooldown } }
        .onReceive(ticker) { _ in if remaining > 0 { remaining -= 1 } }
        .accessibilityLabel(isCoolingDown ? "Resend code, available in \(remaining) seconds" : "Resend code")
    }
}

/// One-box-per-digit code entry. `isError` switches to the rejected-code treatment.
public struct LoginCodeField: View {
    @Binding var code: String
    let digitCount: Int
    let isError: Bool

    @Environment(\.auth0Theme) private var theme
    @FocusState private var focusedField: Int?

    public init(code: Binding<String>, digitCount: Int = 6, isError: Bool = false) {
        self._code = code
        self.digitCount = digitCount
        self.isError = isError
    }

    public var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(0..<digitCount, id: \.self) { digitBox($0) }
        }
        .onAppear { focusedField = 0 }
    }

    private func digitBox(_ index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
        let isFocused = focusedField == index
        return OTPTextField(
            fullText: $code,
            index: index,
            digitCount: digitCount,
            cursorTintColor: isError ? theme.colors.loginError : theme.colors.background.primary,
            setText: { setText($0, at: index) },
            enterKeyPressed: { focusedField = nil },
            emptyBackspaceKeyPressed: emptyBackspace,
            textColor: isError ? theme.colors.loginError : theme.colors.text.bold
        )
        .frame(maxWidth: .infinity)
        .frame(height: theme.sizes.size3xlDimen)
        .background(isError ? theme.colors.background.errorSubtle : theme.colors.background.layerTop, in: shape)
        .overlay(shape.strokeBorder(isError ? theme.colors.errorBorder : theme.colors.border.shadow, lineWidth: 1))
        .overlay {
            if isFocused && !isError {
                shape.strokeBorder(theme.colors.border.subtle, lineWidth: 3)
            }
        }
        .errorRing(isError && isFocused, cornerRadius: theme.radius.medium, color: theme.colors.errorRing)
        .shadow(color: .black.opacity(isError ? 0 : 0.07), radius: 4, x: 0, y: 2)
        .focused($focusedField, equals: index)
    }

    // Mirrors `OTPView.setTextAtIndex` — keeps focus advancing between digits.
    private func setText(_ string: String, at index: Int) {
        let old = code
        let strBefore = old.prefix(length: index)
        let suffixLength = old.count - index - (string.isEmpty ? 1 : string.count)
        let strAfter = suffixLength <= 0 ? "" : old.suffix(length: suffixLength)
        let new = (strBefore + string + strAfter).prefix(length: digitCount)
        code = new

        guard let focusedField else { return }

        if focusedField <= old.count - 1 {
            let newFocus = focusedField + (string.isEmpty ? -1 : string.count)
            self.focusedField = newFocus >= digitCount ? nil : newFocus
            return
        }

        let newFocus = new.count
        self.focusedField = newFocus >= digitCount ? nil : newFocus
    }

    private func emptyBackspace() {
        guard let focusedField, focusedField > 0 else { return }
        self.focusedField = focusedField - 1
    }
}

/// Lenient format check; the server is the source of truth.
enum EmailValidator {
    static func isValid(_ raw: String) -> Bool {
        let email = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { return false }
        return email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}

// MARK: - Shared styling

extension Auth0ColorTokens {
    /// Error text, digits and cursor (#CA3B2B), scoped to Embedded Login.
    var loginError: Color { Color(red: 0xCA / 255, green: 0x3B / 255, blue: 0x2B / 255) }
    /// Hairline border of an invalid field.
    var errorBorder: Color { loginError.opacity(0.18) }
    /// Soft outer ring around a focused invalid field.
    var errorRing: Color { loginError.opacity(0.08) }
}

extension View {
    /// Soft ring drawn just outside the view's rounded bounds.
    func errorRing(_ isVisible: Bool, cornerRadius: CGFloat, color: Color) -> some View {
        overlay {
            if isVisible {
                RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                    .strokeBorder(color, lineWidth: 4)
                    .padding(-3)
            }
        }
    }

    /// Padding and background for an input screen. Only the background ignores the safe area.
    /// - Parameters:
    ///   - horizontalPadding: Side margin; defaults to `spacing.lg`. Second-factor screens use `spacing.xl`.
    ///   - topPadding: Space under the navigation bar; defaults to `spacing.lg`.
    func embeddedScreenChrome(theme: Auth0Theme, horizontalPadding: CGFloat? = nil,
                              topPadding: CGFloat? = nil) -> some View {
        let horizontal = horizontalPadding ?? theme.spacing.lg
        return self
            .padding(EdgeInsets(top: topPadding ?? theme.spacing.lg, leading: horizontal,
                                bottom: theme.spacing.xl, trailing: horizontal))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                ZStack {
                    theme.colors.background.layerBase
                    BrandGradient()
                }
                .ignoresSafeArea()
            }
    }
}
