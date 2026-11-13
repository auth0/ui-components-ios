import SwiftUI

/// Screen title with an optional subtitle and "Edit" action. A masked subtitle (`From (4**)***-*900`) draws its `*`
/// smaller and top-aligned. The subtitle keeps to one line unless `subtitleLineLimit` says otherwise (`nil` wraps).
public struct LoginScreenHeader: View {
    let title: String
    let subtitle: String?
    let subtitleLineLimit: Int?
    let isEditEnabled: Bool
    let onEdit: (() -> Void)?

    @Environment(\.auth0Theme) private var theme

    public init(title: String, subtitle: String? = nil, subtitleLineLimit: Int? = 1, isEditEnabled: Bool = true,
                onEdit: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleLineLimit = subtitleLineLimit
        self.isEditEnabled = isEditEnabled
        self.onEdit = onEdit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(title)
                .auth0TextStyle(theme.typography.body)
                .foregroundStyle(theme.colors.text.bold)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let subtitle {
                HStack(spacing: theme.spacing.sm) {
                    MaskedText(subtitle)
                        .auth0TextStyle(theme.typography.body)
                        .foregroundStyle(theme.colors.text.regular)
                        .lineLimit(subtitleLineLimit)
                        .truncationMode(.middle)
                        .fixedSize(horizontal: false, vertical: true)
                    if let onEdit {
                        Button("Edit", action: onEdit)
                            .buttonStyle(.plain)
                            .auth0TextStyle(theme.typography.title)
                            .foregroundStyle(theme.colors.text.bold)
                            .disabled(!isEditEnabled)
                            .opacity(isEditEnabled ? 1 : 0.4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, subtitle == nil ? 36 : theme.spacing.xxxl)
    }
}
