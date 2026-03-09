import SwiftUI
import Auth0UniversalComponents

struct ThemeView: View {

    // MARK: - View Model
    @StateObject private var viewModel: ThemeViewModel

    // MARK: - Environment
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.auth0Theme) private var theme
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init
    init(viewModel: ThemeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            theme.colors.background.layerBase
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Text("Appearance")
                    .auth0TextStyle(theme.typography.titleLarge)
                    .foregroundStyle(theme.colors.text.bold)
                    .padding(.bottom, theme.spacing.xl)

                Text("THEME")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.text.regular)
                    .padding(.bottom, theme.spacing.xs)

                themeList()

                Spacer()

                updateButton()
            }
            .padding(theme.spacing.lg)
        }
        .onAppear {
            viewModel.selectedOption = themeManager.activeOption
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.colors.text.bold)
                }
            }
        }
    }

    // MARK: - Theme List
    @ViewBuilder
    private func themeList() -> some View {
        VStack(spacing: 0) {
            ForEach(viewModel.options) { option in
                themeRow(for: option)

                if viewModel.options.last != option {
                    Divider()
                        .padding(.leading, theme.spacing.md)
                }
            }
        }
        .background(theme.colors.background.layerTop)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.button))
    }

    // MARK: - Theme Row
    @ViewBuilder
    private func themeRow(for option: ThemeOption) -> some View {
        HStack(spacing: theme.spacing.sm) {
            Text(option.title)
                .auth0TextStyle(theme.typography.body)
                .foregroundStyle(theme.colors.text.bold)

            Spacer()

            RadioButtonView(isSelected: viewModel.selectedOption == option)
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectedOption = option
        }
    }

    // MARK: - Update Button
    @ViewBuilder
    private func updateButton() -> some View {
        Button {
            themeManager.apply(viewModel.selectedOption)
        } label: {
            Text("Update Theme")
                .auth0TextStyle(theme.typography.label)
                .foregroundStyle(theme.colors.text.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: theme.sizes.buttonHeight)
        }
        .background(theme.colors.background.primary)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.button))
        .padding(.bottom, theme.spacing.lg)
    }
}
