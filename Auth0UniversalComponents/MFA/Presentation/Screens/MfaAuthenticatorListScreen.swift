import SwiftUI

/// The factors the user can verify with: one row per phone number, email address or push device.
public struct MfaAuthenticatorListScreen: View {
    let model: AuthenticatorListModel
    let messages: MfaMessages

    @Environment(\.auth0Theme) private var theme

    /// Creates the screen.
    ///
    /// - Parameters:
    ///   - model: What the screen renders and the actions it calls.
    ///   - messages: The words to use.
    public init(model: AuthenticatorListModel, messages: MfaMessages = .default) {
        self.model = model
        self.messages = messages
    }

    private var header: MfaHeaderMessage {
        switch model.header {
        case .challenge: return messages.authenticatorList.headers.challenge
        case .challengeAdditional: return messages.authenticatorList.headers.challengeAdditional
        }
    }

    /// The screen.
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MfaHeader(title: header.title, subtitle: header.description)
                VStack(spacing: theme.spacing.xs) {
                    ForEach(model.rows) { row in
                        MfaFactorRow(row: row, isPending: model.pendingRowID == row.id,
                                     isDisabled: model.pendingRowID != nil) { model.select(row.id) }
                    }
                }
                .padding(.top, theme.spacing.lg)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .mfaScreenChrome(theme: theme, horizontalPadding: theme.spacing.xl,
                              topPadding: theme.spacing.lg + theme.spacing.xxs)
    }
}

/// A tappable factor: icon, what it is, where the code goes, and a chevron (a spinner while its challenge is sent).
/// The factor worded the row itself; nothing here depends on which factor it is.
struct MfaFactorRow: View {
    let row: AuthenticatorListModel.Row
    let isPending: Bool
    let isDisabled: Bool
    let action: () -> Void

    @Environment(\.auth0Theme) private var theme

    private var primary: String { row.title }
    private var secondary: String { row.subtitle ?? "" }

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.md) {
                if let icon = row.icon {
                    Image(icon, bundle: ResourceBundle.default)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: MfaStyle.rowIconSize, height: MfaStyle.rowIconSize)
                        .foregroundStyle(theme.colors.background.primary)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                    Text(primary)
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.text.bold)
                    if !secondary.isEmpty {
                        Text(secondary)
                            .auth0TextStyle(theme.typography.helper)
                            .foregroundStyle(theme.colors.text.regular)
                    }
                }
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.leading, MfaStyle.rowLeading)
            .padding(.trailing, theme.spacing.lg)
            .padding(.vertical, theme.spacing.sm)
            .frame(minHeight: theme.sizes.inputHeight + theme.spacing.xxs)
        }
        .buttonStyle(MfaRowButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled && !isPending ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(secondary.isEmpty ? primary : "\(primary), \(secondary)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var trailing: some View {
        if isPending {
            ProgressView()
                .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
        } else {
            Image("chevron", bundle: ResourceBundle.default)
                .renderingMode(.template)
                .foregroundStyle(theme.colors.background.primary)
                .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
                .accessibilityHidden(true)
        }
    }
}

private let previewRows: [AuthenticatorListModel.Row] = [
    .init(id: "sample:0", factor: "sample", title: "Sudhanshu's iPhone", subtitle: "Approve on this device"),
    .init(id: "sample:1", factor: "sample", title: "iPad", subtitle: "Approve on this device")
]

#Preview("Verify it's you") {
    MfaAuthenticatorListScreen(model: AuthenticatorListModel(header: .challenge, rows: previewRows))
}

#Preview("One more step, sending") {
    MfaAuthenticatorListScreen(model: AuthenticatorListModel(header: .challengeAdditional, rows: previewRows,
                                                             pendingRowID: "sample:0"))
}
