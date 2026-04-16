import SwiftUI
import Auth0UniversalComponents

struct LoginOptionsView: View {

    // MARK: - Properties
    @StateObject private var viewModel: LoginOptionsViewModel
    @State private var selectedOption: LoginOption? = .hostedLogin
    @State private var showAlert: Bool = false
    @State private var showComingSoonDialog: Bool = false

    // MARK: - Router
    @EnvironmentObject var router: Router<SampleAppRoute>
    
    // MARK: - Theme
    @Environment(\.auth0Theme) private var theme

    // MARK: - Init
    init(viewModel: LoginOptionsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Main Body
    var body: some View {
        ZStack(alignment: .center) {
            backgroundView

            VStack(spacing: 0) {
                Image("ic_auth0", bundle: .main)
                    .aspectRatio(106/40, contentMode: .fit)
                    .frame(width: 106)
                    .padding(.top, 60)

                Spacer()

                makeLoginOptionsList()

                Spacer()

                Button {
                    router.navigate(to: .appearance)
                } label: {
                    HStack(spacing: 6) {
                        Image("ic_appearance")

                        Text("Appearance")
                            .auth0TextStyle(theme.typography.title)
                            .foregroundStyle(theme.colors.background.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: theme.sizes.buttonHeight)
                    .padding(.bottom, theme.spacing.xl)
                    .padding(.top, theme.spacing.xxs)
                }
            }
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if !os(macOS)
        .navigationBarBackButtonHidden()
        #endif
        .task {
            let route = await viewModel.checkAuthentication()

            if let route = route {
                router.navigate(to: route)
            }
        }
        .alert("Coming Soon", isPresented: $showComingSoonDialog) {
            Button("Got it", role: .cancel) { selectedOption = nil; showComingSoonDialog = false }
        } message: {
            Text("Feature is currently under development. Stay tuned for updates!")
        }
        .alert("", isPresented: $showAlert) {
            Button("OK", role: .cancel) { selectedOption = nil; showAlert = false }
        } message: {
            Text("Something went wrong!")
        }
        .onChange(of: viewModel.error) { _ in
            if viewModel.error.isNotNil {
                showAlert = true
            }
        }
        .onChange(of: viewModel.navigationRoute) { _ in
            guard let route = viewModel.navigationRoute else { return }
            router.navigate(to: route)
        }
    }

    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        Color.black.opacity(0.25)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: theme.spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(theme.colors.background.primary)
                        .scaleEffect(1.4)

                    Text("Signing in…")
                        .auth0TextStyle(theme.typography.label)
                        .foregroundStyle(theme.colors.text.bold)
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
                .background(theme.colors.background.layerTop)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 8)
            }
    }

    // MARK: - Background
    private var backgroundView: some View {
        GeometryReader { geo in
            ZStack {
                Color("F5F5F5", bundle: .main)
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    LinearGradient(
                      stops: [
                        Gradient.Stop(color: Color(red: 0.97, green: 0.97, blue: 0.96), location: 0.13),
                        Gradient.Stop(color: Color(red: 0.83, green: 0.82, blue: 1), location: 0.28),
                        Gradient.Stop(color: Color(red: 0.97, green: 0.73, blue: 0.47), location: 0.52),
                        Gradient.Stop(color: Color(red: 0.94, green: 0.61, blue: 0.02), location: 0.71),
                        Gradient.Stop(color: Color(red: 0.93, green: 0.92, blue: 0.91), location: 0.99),
                      ],
                      startPoint: UnitPoint(x: 0.24, y: 0.22),
                      endPoint: UnitPoint(x: 0.95, y: 0.24)
                    )
                    .frame(height: geo.size.height/4)
                    .blur(radius: 155.91499)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Login Options List
    @ViewBuilder
    fileprivate func makeLoginOptionsList() -> some View {
        VStack(spacing: 16) {
            Text("Choose how to sign in")
                .auth0TextStyle(theme.typography.display)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, theme.spacing.xs)

            ScrollView {
                VStack(spacing: theme.spacing.sm) {
                    ForEach($viewModel.loginOptionModels, id: \.self) { model in
                        makeLoginOptionView(for: model.wrappedValue)
                    }
                    
                    Button {
                        switch selectedOption {
                        case .hostedLogin:
                            viewModel.performUniversalLogin()
                        default:
                            showComingSoonDialog = true
                        }
                    } label: {
                        HStack {
                            Text("Continue")
                                .foregroundStyle(theme.colors.text.onPrimary)
                                .auth0TextStyle(theme.typography.label)
                        }.frame(maxWidth: .infinity)
                            .padding(.vertical, theme.spacing.sm)
                    }
                    .frame(height: theme.sizes.buttonHeight)
                    .background(theme.colors.background.primary.opacity(selectedOption.isNotNil ? 1.0 : 0.5))
                    .cornerRadius(theme.radius.button)
                    .disabled(selectedOption.isNil)
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.radius.button)
                            .strokeBorder(
                                theme.colors.background.primary.opacity(selectedOption.isNotNil ? 1.0 : 0.5),
                                lineWidth: 2
                            )
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, theme.spacing.lg)
        .padding(.bottom, 132)
    }

    // MARK: - Card View
    @ViewBuilder
    private func makeLoginOptionView(for option: LoginOptionsModel) -> some View {
        getSignInOption(for: option)
            .background(theme.colors.background.layerTop)
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.button))
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.button)
                    .strokeBorder(
                        selectedOption == option.type
                        ? theme.colors.border.bold
                        : theme.colors.border.regular,
                        lineWidth: selectedOption == option.type ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            .disabled(option.type == .embeddedLogin)
            .opacity(option.type != .embeddedLogin ? 1 : 0.4)
            .onTapGesture {
                guard !viewModel.isLoading, option.type != .embeddedLogin else { return }
                selectedOption = option.type
            }
    }

    // MARK: - Card Content
    @ViewBuilder
    private func getSignInOption(for option: LoginOptionsModel) -> some View {
        HStack(alignment: .center, spacing: theme.spacing.md) {
            Image(option.icon, bundle: .main)
                .renderingMode(.template)
                .foregroundStyle(
                    selectedOption == option.type
                    ? theme.colors.background.primary
                    : theme.colors.background.primarySubtle
                )
                .frame(width: theme.sizes.iconMedium, height: theme.sizes.iconMedium)

            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(option.title)
                    .auth0TextStyle(theme.typography.title)
                    .foregroundStyle(theme.colors.text.bold)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Text(option.description)
                    .auth0TextStyle(theme.typography.body)
                    .foregroundStyle(theme.colors.text.regular)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            RadioButtonView(isSelected: selectedOption == option.type)
        }
        .contentShape(Rectangle())
        .padding(.all, theme.spacing.md)
    }
}

extension LoginOptionsView {
    enum LoginOption {
        case embeddedLogin
        case hostedLogin
    }

    struct LoginOptionsModel: Hashable {

        var type: LoginOption
        let icon: String
        let title: String
        let description: String
    }
}
