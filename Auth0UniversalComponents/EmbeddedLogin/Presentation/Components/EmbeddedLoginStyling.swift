import SwiftUI

extension Auth0ColorTokens {
    /// Error text, digits and cursor in Embedded Login: the theme's `foreground.error`.
    var loginError: Color { foreground.error }
    /// Hairline border of an invalid field.
    var errorBorder: Color { loginError.opacity(0.18) }
    /// Soft outer ring around a focused invalid field.
    var errorRing: Color { loginError.opacity(0.08) }
}

extension Auth0Theme {
    /// A field's placeholder: body text in the regular text colour, a step lighter than what is typed (bold).
    func fieldPrompt(_ text: String) -> Text {
        Text(text).font(typography.body.font).foregroundColor(colors.text.regular)
    }
}

extension View {
    /// Soft ring drawn just outside the view's rounded bounds: `width` wide, reaching `overhang` beyond them. An
    /// invalid field wears it in red, and the chosen one of a few choices in grey.
    func softRing(_ isVisible: Bool, cornerRadius: CGFloat, color: Color, width: CGFloat,
                  overhang: CGFloat) -> some View {
        overlay {
            if isVisible {
                RoundedRectangle(cornerRadius: cornerRadius + overhang, style: .continuous)
                    .strokeBorder(color, lineWidth: width)
                    .padding(-overhang)
            }
        }
    }

    /// Padding and background for an input screen. Only the background ignores the safe area.
    /// - Parameters:
    ///   - horizontalPadding: Side margin; defaults to `spacing.lg`. Factor screens use `spacing.xl`.
    ///   - topPadding: Space under the navigation bar; defaults to `spacing.lg`.
    ///   - scrolls: Whether the content scrolls (and a drag dismisses the keyboard) when the keyboard or large text
    ///     leaves too little room. Content that fits looks the same, and a bottom-pinned `Spacer` still pins.
    func embeddedScreenChrome(theme: Auth0Theme, horizontalPadding: CGFloat? = nil, topPadding: CGFloat? = nil,
                              scrolls: Bool = false) -> some View {
        let horizontal = horizontalPadding ?? theme.spacing.lg
        let insets = EdgeInsets(top: topPadding ?? theme.spacing.lg, leading: horizontal,
                                bottom: theme.spacing.xl, trailing: horizontal)
        return modifier(EmbeddedScreenChrome(insets: insets, scrolls: scrolls))
    }
}

private struct EmbeddedScreenChrome: ViewModifier {
    let insets: EdgeInsets
    let scrolls: Bool

    private static let contentID = "content"

    @Environment(\.auth0Theme) private var theme

    func body(content: Content) -> some View {
        Group {
            if scrolls {
                // The view is as tall as what the keyboard leaves, so centered content stays centered in it. When it
                // doesn't fit, the keyboard coming up scrolls to the bottom, where Continue is.
                GeometryReader { proxy in
                    ScrollViewReader { scroll in
                        ScrollView {
                            content
                                .padding(insets)
                                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .top)
                                .id(Self.contentID)
                        }
                        .scrollDismissesKeyboardInteractively()
                        .scrollBounceBasedOnSize()
                        .onKeyboardShown {
                            withAnimation(.easeOut(duration: 0.25)) { scroll.scrollTo(Self.contentID, anchor: .bottom) }
                        }
                    }
                }
            } else {
                content
                    .padding(insets)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .background {
            ZStack {
                theme.colors.background.layerBase
                BrandGradient()
            }
            .ignoresSafeArea()
        }
    }
}
