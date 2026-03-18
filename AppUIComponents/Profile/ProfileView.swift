import SwiftUI
import Auth0UniversalComponents

struct ProfileView: View {

    // MARK: - Properties
    @StateObject private var viewModel: ProfileViewModel

    // MARK: - Router
    @EnvironmentObject var router: Router<SampleAppRoute>

    // MARK: - Environment
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.auth0Theme) private var theme

    // MARK: - Init
    init(viewModel: ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Main view
    var body: some View {
        ZStack {
            theme.colors.background.layerBase
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.xl) {
                    profileHeader()

                    ForEach(viewModel.sections) { section in
                        sectionView(section)
                    }
                }
                .padding(theme.spacing.lg)
            }
        }
        .onAppear {
            viewModel.attach(to: themeManager)
        }
        #if !os(macOS)
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar {
            ToolbarItem(placement: .platformLeading) {
                Button {
                    router.pop()
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(theme.colors.text.bold)
                }
            }
        }
    }

    // MARK: - Profile Header
    @ViewBuilder
    private func profileHeader() -> some View {
        VStack(spacing: theme.spacing.sm) {
            Text(viewModel.displayName)
                .auth0TextStyle(theme.typography.displayLarge)
                .foregroundStyle(theme.colors.text.bold)

            if !viewModel.lastUpdatedText.isEmpty {
                Text(viewModel.lastUpdatedText)
                    .auth0TextStyle(theme.typography.body)
                    .foregroundStyle(theme.colors.text.regular)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacing.xxl)
    }

    // MARK: - Section View
    @ViewBuilder
    private func sectionView(_ section: ProfileSection) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.md) {
            
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(section.title)
                    .auth0TextStyle(theme.typography.titleLarge)
                    .foregroundStyle(theme.colors.text.bold)
                
                if let description = section.description {
                    Text(description)
                        .auth0TextStyle(theme.typography.body)
                        .foregroundStyle(theme.colors.text.regular)
                }
            }

            sectionCard(for: section.rows)
        }
    }

    // MARK: - Section Card
    @ViewBuilder
    private func sectionCard(for rows: [ProfileOptionRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                rowView(for: row)

                if index < rows.count - 1 {
                    Divider()
                        .foregroundStyle(theme.colors.border.subtle)
                        .padding(.leading, theme.spacing.md)
                        .padding(.trailing, theme.spacing.sm)
                }
            }
        }
        .background(theme.colors.background.layerTop)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.medium)
                .inset(by: 0.5)
                .stroke(theme.colors.border.subtle, lineWidth: 1)
        }
    }

    // MARK: - Row View
    @ViewBuilder
    private func rowView(for row: ProfileOptionRow) -> some View {
        HStack(spacing: theme.spacing.md) {
            if let icon = row.icon {
                Image(systemName: icon)
                    .foregroundStyle(theme.colors.text.regular)
                    .frame(width: theme.sizes.iconMedium)
            }

            Text(row.title)
                .auth0TextStyle(row.icon.isNil ? theme.typography.title : theme.typography.body)
                .foregroundStyle(theme.colors.text.bold)

            Spacer()

            if let detail = row.detail {
                Text(detail)
                    .auth0TextStyle(theme.typography.body)
                    .foregroundStyle(theme.colors.text.regular)
            }

            if row.route.isNotNil {
                Image(systemName: "chevron.right")
                    .resizable()
                    .foregroundStyle(theme.colors.background.primary)
                    .padding(.vertical, theme.spacing.xxs)
                    .padding(.horizontal, 6)
                    .frame(width: theme.sizes.iconSmall, height: theme.sizes.iconSmall)
            }
        }
        .padding(theme.spacing.md)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let route = row.route else { return }
            router.navigate(to: route)
        }
    }
}
