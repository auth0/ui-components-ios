import SwiftUI

/// Full-width capsule that inverts with the color scheme.
struct PrimaryPillButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
        }
        .foregroundStyle(scheme == .dark ? Color.black : Color.white)
        .background(scheme == .dark ? Color.white : Color.black, in: Capsule())
        .buttonStyle(.plain)
    }
}
