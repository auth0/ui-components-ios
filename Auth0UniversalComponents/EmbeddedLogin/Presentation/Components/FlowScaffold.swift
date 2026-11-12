import SwiftUI

/// Centered content with a bottom-anchored actions row.
struct FlowScaffold<Content: View, Actions: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            content()
            Spacer()
            actions()
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
