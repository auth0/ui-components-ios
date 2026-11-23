import SwiftUI

/// Top bar with a back arrow and, when it has one, a centered title.
public struct LoginNavigationBar: View {
    let title: String?
    let isBackEnabled: Bool
    let onBack: (() -> Void)?

    @Environment(\.auth0Theme) private var theme

    /// - Parameter title: `nil` leaves the bar with only its back arrow.
    public init(title: String? = "Log in", isBackEnabled: Bool = true, onBack: (() -> Void)? = nil) {
        self.title = title
        self.isBackEnabled = isBackEnabled
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .auth0TextStyle(theme.typography.title)
                    .foregroundStyle(theme.colors.text.bold)
            }
            if let onBack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: theme.sizes.navigationIcon, weight: .regular))
                            .foregroundStyle(theme.colors.text.bold)
                            .frame(width: theme.sizes.tapTarget, height: theme.sizes.tapTarget)
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
        .frame(height: theme.sizes.tapTarget)
        .padding(.horizontal, theme.spacing.xs)
    }
}
