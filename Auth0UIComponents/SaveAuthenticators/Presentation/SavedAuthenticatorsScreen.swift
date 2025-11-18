import SwiftUI
import Auth0

struct SavedAuthenticatorsScreen: View {
    @ObservedObject var viewModel: SavedAuthenticatorsScreenViewModel
    var body: some View {
        ZStack {
            if viewModel.showLoader {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(Color("3C3C43", bundle: ResourceBundle.default))
                    .scaleEffect(1.5 )
                    .frame(width: 50, height: 50)
            } else if let errorViewModel = viewModel.errorViewModel {
                ErrorScreen(viewModel: errorViewModel)
            } else {
                VStack(alignment: .leading) {
                    Text(viewModel.type.savedAuthenticatorsTitle)
                        .font(.system(size: 14))
                        .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                        .padding(.bottom, 8)
                    if viewModel.viewAuthenticationMethods.isEmpty {
                        Text(viewModel.type.savedAuthenticatorsEmptyStateMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(Color("000000_24", bundle: ResourceBundle.default))
                            .padding(.vertical, 25.5)
                            .frame(maxWidth: .infinity)
                            .background(Color("F9F9F9", bundle: ResourceBundle.default))
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack {
                                ForEach(viewModel.viewAuthenticationMethods, id: \.self) { authMethod in
                                    AuthenticatorView(type: viewModel.type, authenticationMethod: authMethod, showManageBottomSheet: $viewModel.showManageAuthSheet)
                                        .confirmationDialog(viewModel.type.confirmationDialogTitle, isPresented: $viewModel.showManageAuthSheet, titleVisibility: .visible) {
                                            Button(viewModel.type.confirmationDialogDestructiveButtonTitle, role: .destructive) {
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
        }.navigationTitle(viewModel.type.savedAuthenticatorsNavigationTitle)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: trailingPlacement) {
                    Image("plus", bundle: ResourceBundle.default)
                        .onTapGesture {
                            NavigationStore.shared.push(viewModel.type.navigationDestination([]))
                        }
                }
                
                ToolbarItem(placement: leadingPlacement) {
                    Image("back", bundle: ResourceBundle.default)
                        .onTapGesture {
                            NavigationStore.shared.popToRoot()
                        }
                }
            }.onAppear {
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
            return . navigation
            #else
            return .topBarLeading
            #endif
        }
}

struct AuthenticatorView: View {
    let type: AuthMethodType
    let authenticationMethod: AuthenticationMethod
    @Binding var showManageBottomSheet: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(type.savedAuthenticatorsCellTitle)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color("000000", bundle: ResourceBundle.default))

                Text("Created")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("828282", bundle: ResourceBundle.default))

                Text("Last used")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("828282", bundle: ResourceBundle.default))
            }
            Spacer()
            Image("threedots", bundle: ResourceBundle.default)
                .frame(width: 28, height: 28)
                .onTapGesture {
                    DispatchQueue.main.async {
                        showManageBottomSheet = true
                    }
                }
        }.padding()
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("D9D9D9", bundle: ResourceBundle.default), lineWidth: 1)
            }
    }
}
