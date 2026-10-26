import SwiftUI

/// Centered title with an optional secondary message.
struct StatusText: View {
    let title: String
    var message: String?

    var body: some View {
        Text(title)
            .font(.title).fontWeight(.semibold)
            .multilineTextAlignment(.center)
        if let message {
            Text(message)
                .font(.body).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
