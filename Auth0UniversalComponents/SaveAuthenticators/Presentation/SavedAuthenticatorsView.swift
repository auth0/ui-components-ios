import SwiftUI
import Auth0

/// Screen for selecting and managing saved authentication methods.
///
/// Displays a list of previously enrolled authentication methods for a specific
/// type (email, SMS, TOTP, push, etc.) that users can select to manage or delete.
struct SavedAuthenticatorsView: View {

    @Environment(\.auth0Theme) private var theme
    @EnvironmentObject private var router: Router<Route>
    /// View model managing saved authenticators and deletion logic
    @StateObject private var viewModel: SavedAuthenticatorsViewModel

    /// Initializes the saved authenticators screen.
    ///
    /// - Parameter viewModel: The view model managing saved authenticators and deletion logic
    init(viewModel: SavedAuthenticatorsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            if viewModel.showLoader {
                Auth0Loader()
            } else if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel)
            } else {
                VStack(alignment: .leading) {
                    Text(viewModel.type.savedAuthenticatorsTitle)
                        .auth0TextStyle(theme.typography.helper)
                        .foregroundStyle(theme.colors.text.regular)
                        .padding(.bottom, theme.spacing.xs)

                    if viewModel.viewAuthenticationMethods.isEmpty {
                        Text(viewModel.type.savedAuthenticatorsEmptyStateMessage)
                            .auth0TextStyle(theme.typography.helper)
                            .foregroundStyle(theme.colors.text.regular)
                            .padding(.vertical, theme.spacing.lg)
                            .frame(maxWidth: .infinity)
                            .background(theme.colors.background.layerMedium)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack {
                                ForEach(viewModel.viewAuthenticationMethods, id: \.self) { authMethod in
                                    AuthenticatorView(type: viewModel.type,
                                                      authenticationMethod: authMethod,
                                                      onDelete: {
                                        await viewModel.deleteAuthMethod(authMethod: authMethod)
                                    })
                                }
                            }
                        }
                    }
                }
                .padding(EdgeInsets(top: theme.spacing.lg,
                                    leading: theme.spacing.md,
                                    bottom: theme.spacing.lg,
                                    trailing: theme.spacing.md))
            }
        }
        .navigationTitle(viewModel.type.savedAuthenticatorsNavigationTitle)
        #if !os(macOS)
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar {
            ToolbarItem(placement: trailingPlacement) {
                Image("plus", bundle: ResourceBundle.default)
                    .onTapGesture {
                        router.navigate(to: viewModel.type.navigationDestination([]))
                    }
            }

            ToolbarItem(placement: leadingPlacement) {
                Image("back", bundle: ResourceBundle.default)
                    .onTapGesture {
                        router.pop()
                    }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
        .background(theme.colors.background.layerBase)
    }

    var trailingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .automatic
        #else
        return .topBarTrailing
        #endif
    }

    var leadingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .navigation
        #else
        return .topBarLeading
        #endif
    }
}

