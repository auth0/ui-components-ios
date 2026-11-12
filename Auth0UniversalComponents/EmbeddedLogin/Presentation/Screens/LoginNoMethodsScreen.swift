import SwiftUI

/// Discovery returned nothing this flow can drive. `onBack` defaults to dismissing.
public struct LoginNoMethodsScreen: View {
    let onBack: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    public init(onBack: (() -> Void)? = nil) { self.onBack = onBack }

    public var body: some View {
        FlowScaffold {
            Image(systemName: "nosign")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            StatusText(title: "No sign-in methods available",
                       message: "This tenant didn't return any sign-in options the app can present right now.")
        } actions: {
            PrimaryPillButton(title: "Go back") { (onBack ?? { dismiss() })() }
        }
    }
}

#Preview("No methods") { LoginNoMethodsScreen() }
