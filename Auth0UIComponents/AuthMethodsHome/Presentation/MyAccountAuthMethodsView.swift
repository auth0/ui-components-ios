import SwiftUI
import Combine

public struct MyAccountAuthMethodsView: View {
    
    // MARK: - Navigation
    @StateObject private var navigationStore = NavigationStore.shared
    
    // MARK: - State Properties
    @State private var previousPathCount = 0
    
    // MARK: - View Model
    @ObservedObject private var viewModel: MyAccountAuthMethodsViewModel
    
    // MARK: - Init
    public init() {
        self.viewModel = MyAccountAuthMethodsViewModel()
    }

    // MARK: - Main body
    public var body: some View {
        NavigationStack(path: $navigationStore.path) {
            ZStack {
                if viewModel.showLoader {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(Color("3C3C43", bundle: ResourceBundle.default))
                        .scaleEffect(1.5)
                        .frame(width: 50, height: 50)
                }
                else if let errorViewModel = viewModel.errorViewModel {
                    ErrorScreen(viewModel: errorViewModel)
                        .padding()
                }
                else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading) {
                            ForEach(viewModel.viewComponents, id: \.self) { component in
                                authMethodView(component)
                            }
                        }.padding(.all, 16)
                    }
                }
            }
            .navigationTitle(Text("Login & Security"))
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .navigationDestination(for: Route.self) { route in
                    handleRoute(route: route, delegate: viewModel)
                }
        }.onReceive(navigationStore.$path) { path in
            if path.count < previousPathCount && path.isEmpty {
                Task {
                    await viewModel.loadMyAccountAuthViewComponentData()
                }
            }
            previousPathCount = path.count
        }
        .onAppear {
            Task {
                await viewModel.loadMyAccountAuthViewComponentData()
            }
        }
    }

    @ViewBuilder
    private func authMethodView(_ component: MyAccountAuthViewComponentData) -> some View {
        switch component {
        case .title(let text):
            Text(text)
                .textStyle(.title)
        case .subtitle(let text):
            Text(text)
                .textStyle(.bodySmall)
        case .additionalVerificationMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel)
        case .emptyFactors:
            EmptyFactorsView()
        }
    }

    @ViewBuilder
    private func handleRoute(route: Route, delegate: RefreshAuthDataProtocol?) -> some View {
        switch route {
        case let .totpPushQRScreen(type):
            TOTPPushQRCodeView(viewModel: TOTPPushQRCodeViewModel(type: type, delegate: delegate))
        case let .otpScreen(type,
                            emailOrPhoneNumber,
                            totpEnrollmentChallege,
                            phoneEnrollmentChallenge,
                            emailEnrollmentChallenge):
            OTPView(viewModel: OTPViewModel(
                totpEnrollmentChallenge: totpEnrollmentChallege,
                emailEnrollmentChallenge: emailEnrollmentChallenge,
                phoneEnrollmentChallenge: phoneEnrollmentChallenge,
                type: type,
                emailOrPhoneNumber: emailOrPhoneNumber,
                delegate: delegate
            ))
        case let .filteredAuthListScreen(type, authMethods):
            SavedAuthenticatorsScreen(viewModel: SavedAuthenticatorsScreenViewModel(
                type: type,
                authenticationMethods: authMethods,
                delegate: delegate
            ))
        case let .emailPhoneEnrollmentScreen(type):
            EmailPhoneEnrollmentView(viewModel: EmailPhoneEnrollmentViewModel(type: type))
        case .recoveryCodeScreen:
            RecoveryCodeEnrollmentView(viewModel: RecoveryCodeEnrollmentViewModel(delegate: delegate))
        }
    }
}
