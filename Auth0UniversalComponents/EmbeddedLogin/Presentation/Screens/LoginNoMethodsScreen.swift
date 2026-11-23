import SwiftUI

/// Discovery returned nothing this flow can drive. `onBack` defaults to dismissing.
public struct LoginNoMethodsScreen: View {
    let onBack: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.auth0Theme) private var theme

    public init(onBack: (() -> Void)? = nil) { self.onBack = onBack }

    public var body: some View {
        StatusLayout(
            title: "No sign-in methods available",
            message: "This tenant didn't return any sign-in options the app can present right now.",
            icon: StatusIcon(systemName: "nosign", color: theme.colors.text.regular)
        ) {
            LoginPrimaryButton("Go back") { (onBack ?? { dismiss() })() }
        }
    }
}

#Preview("No methods") { LoginNoMethodsScreen() }
