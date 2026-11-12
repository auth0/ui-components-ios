import SwiftUI

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

#Preview("Success") { LoginSuccessScreen() }
