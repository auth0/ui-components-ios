import SwiftUI
import Auth0UniversalComponents

struct WelcomeView: View {

    // MARK: - Properties
    @StateObject private var viewModel: WelcomeViewModel
    @State private var tileHeight: CGFloat = 0

    // MARK: - Router
    @EnvironmentObject var router: Router<SampleAppRoute>

    // MARK: - Theme
    @Environment(\.auth0Theme) private var theme

    // MARK: - Init
    init(viewModel: WelcomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Main body
    var body: some View {
        VStack(alignment: .center, spacing: theme.spacing.lg) {

            headerView()

            makeAvailableOptionsList()

            logoutButton()
        }
        .padding(theme.spacing.xl)
        .padding(.top, theme.spacing.xxl)
        #if !os(macOS)
        .navigationBarBackButtonHidden()
        #endif
        .background(theme.colors.background.layerBase)
    }

    // MARK: - Header View
    @ViewBuilder
    private func headerView() -> some View {
        VStack(spacing: theme.spacing.xs) {
            Text("Hi, \(viewModel.userName)")
                .auth0TextStyle(theme.typography.displayMedium)
                .foregroundStyle(theme.colors.text.bold)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            Text("Discover how to utilize auth0's powerful native SDK and account API in this app.")
                .auth0TextStyle(theme.typography.body)
                .foregroundStyle(theme.colors.text.regular)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private func makeAvailableOptionsList() -> some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        ScrollView {
            LazyVGrid(columns: columns, spacing: theme.spacing.md) {
                ForEach($viewModel.options) { item in
                    optionTile(for: item)
                }
            }
        }
        .onPreferenceChange(TileHeightKey.self) { tileHeight = $0 }
    }

    // MARK: - Option Tile
    @ViewBuilder
    private func optionTile(for item: Binding<WelcomeOptionsModel>) -> some View {
        let isAvailable = item.route.wrappedValue != nil

        VStack(alignment: .leading, spacing: 0) {
            Image(item.icon.wrappedValue, bundle: .main)
                .padding(theme.spacing.xxs)
                .frame(width: theme.sizes.iconLarge, height: theme.sizes.iconLarge)

            // Flexible gap: collapses to minLength on natural height,
            // expands to push the title to the bottom when a uniform
            // height is enforced across all tiles.
            Spacer(minLength: theme.spacing.lg)

            Text(item.title.wrappedValue)
                .auth0TextStyle(theme.typography.title)
                .foregroundStyle(theme.colors.text.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.spacing.lg)
        // On the first pass tileHeight is 0 so tiles render at their natural
        // height. Once the PreferenceKey reports the maximum, all tiles are
        // given that fixed height so the Spacer can push the title to the bottom.
        .frame(maxWidth: .infinity, minHeight: tileHeight > 0 ? tileHeight : nil)
        .contentShape(Rectangle())
        .background(theme.colors.background.layerMedium)
        .cornerRadius(20)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 0.5)
                .stroke(theme.colors.border.regular, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .opacity(isAvailable ? 1 : 0.4)
        .disabled(!isAvailable)
        .onTapGesture {
            guard let route = item.route.wrappedValue else { return }
            router.navigate(to: route)
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: TileHeightKey.self, value: geo.size.height)
            }
        )
    }

    @ViewBuilder
    private func logoutButton() -> some View {
        Button {
            viewModel.performLogout {
                router.pop()
            }
        } label: {
            Text("Log out")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("262420", bundle: .main))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
        }
    }
}

private struct TileHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
