import SwiftUI

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
