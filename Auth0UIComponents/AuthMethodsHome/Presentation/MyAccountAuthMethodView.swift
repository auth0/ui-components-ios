import SwiftUI

struct MyAccountAuthMethodView: View {
    @ObservedObject var viewModel: MyAccountAuthMethodViewModel

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
