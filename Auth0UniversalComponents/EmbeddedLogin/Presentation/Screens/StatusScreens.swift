import SwiftUI

// Status screens for transient/terminal steps. Standalone: plain values in, closures out.

/// Centered spinner over the brand gradient.
public struct LoginLoadingScreen: View {
    @Environment(\.auth0Theme) private var theme

    public init() {}

    public var body: some View {
        ZStack {
            theme.colors.background.layerBase.ignoresSafeArea()
            BrandGradient()
            // Keeps the spinner still while the keyboard animates.
            BrandSpinner()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.keyboard)
        }
    }
}

/// Message with a "Try again" action, biased slightly above center.
public struct LoginErrorScreen: View {
    let message: String
    let onRetry: () -> Void

    public init(message: String = "", onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }

    public var body: some View {
        VStack(spacing: 14) {
            Spacer()
            StatusText(title: "Sign in couldn't be completed.",
                       message: message.isEmpty ? "We are unable to process your request. Please try again in a few minutes." : message)
            PrimaryPillButton(title: "Try again", action: onRetry)
                .padding(.top, 18)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Shown briefly before the host routes away.
public struct LoginSuccessScreen: View {
    public init() {}

    public var body: some View {
        FlowScaffold {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            StatusText(title: "You're signed in")
        } actions: {
            EmptyView()
        }
    }
}

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

// MARK: - Previews

#Preview("Loading") { LoginLoadingScreen() }
#Preview("Error") { LoginErrorScreen {} }
#Preview("Success") { LoginSuccessScreen() }
#Preview("No methods") { LoginNoMethodsScreen() }
