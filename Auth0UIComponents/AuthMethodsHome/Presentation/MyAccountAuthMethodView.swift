import SwiftUI

struct MyAccountAuthMethodView: View {
    @ObservedObject var viewModel: MyAccountAuthMethodViewModel
    struct Constants {
        static let colorPrimary0: Color = Color(red: 0.15, green: 0.14, blue: 0.13).opacity(0)
        static let colorPrimary5: Color = Color(red: 0.15, green: 0.14, blue: 0.13).opacity(0.05)
    }
    
    var body: some View {
        HStack() {
            Image(viewModel.image(), bundle: ResourceBundle.default)
                .frame(width: 24, height: 24)
                .padding(.trailing, 16)
            Text(viewModel.title())
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                .padding(.trailing, 16)
            Spacer()
            if viewModel.isAtleastOnceAuthFactorEnrolled() {
                Image("checkmark.green", bundle: ResourceBundle.default)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 22)
            }
            Image("chevron", bundle: ResourceBundle.default)
                .frame(width: 16, height: 16)
        }.padding(.all, 20)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("D9D9D9", bundle: ResourceBundle.default), lineWidth: 1)
                    .background(
                        LinearGradient(
                            stops: [
                                Gradient.Stop(color: Constants.colorPrimary0, location: 0.00),
                                Gradient.Stop(color: Constants.colorPrimary5, location: 1.00),
                            ],
                            startPoint: UnitPoint(x: 0.5, y: 0),
                            endPoint: UnitPoint(x: 0.5, y: 1)
                        )
                    )
                    .cornerRadius(16)
                
            }
            .onTapGesture {
                viewModel.handleNavigation()
            }
    }
}
