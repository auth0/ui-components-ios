import SwiftUI

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
