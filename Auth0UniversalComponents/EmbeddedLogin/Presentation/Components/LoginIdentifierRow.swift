import SwiftUI

/// Who is signing in, shaped like the field it was typed in but read-only: the email, number or username from the
/// screen before, under the label that field had, with "Edit" at the end to go back and change it.
struct LoginIdentifierRow: View {
    let label: String
    let value: String
    let isEditEnabled: Bool
    /// `nil` hides Edit.
    let onEdit: (() -> Void)?

    @Environment(\.auth0Theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LoginFieldLabel(label)
            LoginInputField {
                Text(value)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } trailing: {
                if let onEdit {
                    Button("Edit", action: onEdit)
                        .buttonStyle(.plain)
                        .auth0TextStyle(theme.typography.title)
                        .foregroundStyle(theme.colors.text.bold)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .disabled(!isEditEnabled)
                        .opacity(isEditEnabled ? 1 : 0.4)
                        .accessibilityLabel("Edit \(label.lowercased())")
                }
            }
        }
    }
}

#Preview("Row") {
    LoginIdentifierRow(label: "Email", value: "sarah.doe@atko.email", isEditEnabled: true, onEdit: {})
        .padding()
}

#Preview("Row – long, no edit") {
    LoginIdentifierRow(label: "Email", value: "a.very.long.address.for.a.long.name@subdomain.example-company.com",
                       isEditEnabled: true, onEdit: nil)
        .padding()
}
