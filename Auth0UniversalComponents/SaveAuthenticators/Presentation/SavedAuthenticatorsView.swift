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
                            .padding(.vertical, 25.5)
                            .frame(maxWidth: .infinity)
                            .background(theme.colors.background.layerMedium)
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack {
                                ForEach(viewModel.viewAuthenticationMethods, id: \.self) { authMethod in
                                    AuthenticatorView(type: viewModel.type,
                                                      authenticationMethod: authMethod,
                                                      showManageBottomSheet: $viewModel.showManageAuthSheet)
                                        .confirmationDialog(viewModel.type.confirmationDialogTitle,
                                                            isPresented: $viewModel.showManageAuthSheet,
                                                            titleVisibility: .visible) {
                                            Button(viewModel.type.confirmationDialogDestructiveButtonTitle,
                                                   role: .destructive) {
                                                Task {
                                                   await viewModel.deleteAuthMethod(authMethod: authMethod)
                                                }
                                            }
                                        }
                                }
                            }
                        }
                    }
                }.padding(EdgeInsets(top: 24, leading: 16, bottom: 24, trailing: 16))
            }
        }
        .navigationTitle(viewModel.type.savedAuthenticatorsNavigationTitle)
        .navigationBarBackButtonHidden(true)
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

struct AuthenticatorView: View {

    @Environment(\.auth0Theme) private var theme

    let type: AuthMethodType
    let authenticationMethod: AuthenticationMethod
    @Binding var showManageBottomSheet: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(authenticationMethod.name ?? type.savedAuthenticatorsCellTitle)
                    .auth0TextStyle(theme.typography.label)
                    .foregroundStyle(theme.colors.text.bold)

                Text("Created on \(authenticationMethod.formatIsoDate)")
                    .auth0TextStyle(theme.typography.helper)
                    .foregroundStyle(theme.colors.text.regular)
            }
            Spacer()
            Image("threedots", bundle: ResourceBundle.default)
                .frame(width: theme.sizes.iconLarge, height: theme.sizes.iconLarge)
                .onTapGesture {
                    DispatchQueue.main.async {
                        showManageBottomSheet = true
                    }
                }
        }
        .padding()
        .overlay {
            RoundedRectangle(cornerRadius: theme.radius.button)
                .stroke(theme.colors.border.regular, lineWidth: 1)
        }
    }
}
