import SwiftUI
import Auth0

/// Displays a single authentication method as a selectable card.
///
/// This view shows one authentication method (email, SMS, TOTP, push, passkeys, or recovery codes)
/// with an icon, title, and enrollment status indicator. It is tappable to navigate to the
/// management or enrollment screen for that authentication method.
struct MyAccountAuthMethodView: View {
    /// View model providing authentication method details and actions
    @StateObject var viewModel: MyAccountAuthMethodViewModel
 
    init(viewModel: MyAccountAuthMethodViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        HStack() {
            Image(viewModel.image(), bundle: ResourceBundle.default)
                .frame(width: 24, height: 24)
                .padding(.trailing, 16)

            Text(viewModel.title())
                .textStyle(.body)
                .padding(.trailing, 16)

            Spacer()

            if viewModel.isAtleastOnceAuthFactorEnrolled() {
                Image("checkmark.green", bundle: ResourceBundle.default)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 22)
            }
            Image("chevron", bundle: ResourceBundle.default)
                .frame(width: 16, height: 16)
        }
        .padding(.all, 20)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("D9D9D9", bundle: ResourceBundle.default), lineWidth: 1)
        }
        .onTapGesture {
            viewModel.handleNavigation()
        }
    }
}
