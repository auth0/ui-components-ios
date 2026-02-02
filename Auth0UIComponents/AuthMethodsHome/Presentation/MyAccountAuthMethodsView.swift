import SwiftUI
import Combine

public struct MyAccountAuthMethodsView: View {
    @StateObject private var navigationStore = NavigationStore.shared
    @ObservedObject private var viewModel: MyAccountAuthMethodsViewModel
    @State private var previousPathCount = 0
    @State var collapsePasskeyBanner: Bool = false
    public init() {
        self.viewModel = MyAccountAuthMethodsViewModel()
    }

    public var body: some View {
        NavigationStack(path: $navigationStore.path) {
            ZStack {
                if viewModel.showLoader {
                    Auth0Loader()
                }
                else if let errorViewModel = viewModel.errorViewModel {
                    ErrorScreen(viewModel: errorViewModel)
                        .padding() // Adds spacing from screen edges
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
        case .createPasskey(let model):
            if #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) {
                if let viewModel = model as? PasskeysEnrollmentViewModel,
                    collapsePasskeyBanner == false {
                    EnrollPasskeyView(collapsePasskeyBanner: $collapsePasskeyBanner,
                                      viewModel: viewModel)
                        .padding(.bottom, 24)
                }
            }
        case .signinMethods(let viewModel):
            MyAccountAuthMethodView(viewModel: viewModel)
                .padding(.bottom, 48)
        case .title(let text):
            Text(text)
                .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                .font(.system(size: 20, weight: .semibold))

        case .subtitle(let text):
            Text(text)
                .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                .font(.system(size: 14, weight: .regular))

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
        case .enrollPasskeyScreen:
            if #available(iOS 16.6, macOS 13.5, visionOS 1.0, *) {
                PasskeysEnrollmentView(viewModel: PasskeysEnrollmentViewModel(delegate: delegate))
            }
        }
    }
}
