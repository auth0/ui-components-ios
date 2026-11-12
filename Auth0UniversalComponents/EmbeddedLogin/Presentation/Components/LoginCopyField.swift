import SwiftUI

/// The label, a value that is shown rather than typed, and a button that copies it. A short "Copied" bubble over the
/// button confirms it.
struct LoginCopyField: View {
    let label: String
    let value: String
    /// What the bubble says.
    let copiedTitle: String
    /// What VoiceOver calls the button.
    let copyLabel: String

    @Environment(\.auth0Theme) private var theme
    @State private var isCopiedShown: Bool
    @State private var hideTask: Task<Void, Never>?

    /// - Parameter startsCopied: Opens with the bubble showing, and keeping it: for previews and screenshots.
    init(label: String, value: String, copiedTitle: String, copyLabel: String, startsCopied: Bool = false) {
        self.label = label
        self.value = value
        self.copiedTitle = copiedTitle
        self.copyLabel = copyLabel
        _isCopiedShown = State(initialValue: startsCopied)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginFieldLabel(label)
            LoginInputField(content: {
                Text(value)
                    .foregroundStyle(theme.colors.text.regular)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }, trailing: {
                Button(action: copy) {
                    Image(systemName: "square.on.square")
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.colors.text.bold)
                .accessibilityLabel(copyLabel)
                // Faded in and out, not inserted: a transition would drop the guide that lifts it above the button.
                .overlay(alignment: .top) {
                    CopiedBubble(title: copiedTitle)
                        .opacity(isCopiedShown ? 1 : 0)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                        .alignmentGuide(.top) { $0[.bottom] + theme.spacing.sm }
                }
            })
        }
        .onDisappear { hideTask?.cancel() }
    }

    private func copy() {
        SecretPasteboard.copy(value)
        withAnimation(.easeOut(duration: 0.15)) { isCopiedShown = true }
        // The bubble is for the eyes: VoiceOver is told instead.
        if #available(iOS 17, macOS 14, *) { AccessibilityNotification.Announcement(copiedTitle).post() }
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.2)) { isCopiedShown = false }
        }
    }
}

/// A small dark bubble pointing down at the button it confirms.
private struct CopiedBubble: View {
    let title: String
    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .auth0TextStyle(theme.typography.bodySmall)
                .foregroundStyle(theme.colors.text.onPrimary)
                .padding(.horizontal, theme.spacing.sm)
                .padding(.vertical, theme.spacing.xs)
                .background(theme.colors.background.primary, in: RoundedRectangle(cornerRadius: theme.radius.medium))
            BubblePointer()
                .fill(theme.colors.background.primary)
                .frame(width: 12, height: 6)
        }
        .fixedSize()
    }
}

private struct BubblePointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Copy field") {
    LoginCopyField(label: "Recovery Code", value: "YHARATFUJJKZNV5N3X1L2ZEC", copiedTitle: "Copied",
                   copyLabel: "Copy recovery code")
        .padding()
}

#Preview("Copy field – copied") {
    LoginCopyField(label: "Recovery Code", value: "YHARATFUJJKZNV5N3X1L2ZEC", copiedTitle: "Copied",
                   copyLabel: "Copy recovery code", startsCopied: true)
        .padding()
}
