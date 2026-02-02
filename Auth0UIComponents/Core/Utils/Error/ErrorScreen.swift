import SwiftUI

/// Displays an error message screen to the user.
///
/// This view presents an error state with a title, detailed message, and an action button.
/// It is used throughout Auth0 UI Components to display error states from failed operations.
struct ErrorScreen: View {
    /// The view model providing error information and callbacks
    let viewModel: ErrorScreenViewModel

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Text(viewModel.title)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Color("191919", bundle: ResourceBundle.default))
                
                Text(viewModel.subTitle)
                    .onTapGesture {
                        viewModel.handleTextTap()
                    }
                
                Button {
                    viewModel.handleButtonClick()
                } label: {
                    Text(viewModel.buttonTitle)
                        .foregroundStyle(Color.white)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                }.frame(height: 48)
                    .background(
                        Color("262420", bundle: ResourceBundle.default)
                    )
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color("262420", bundle: ResourceBundle.default),
                                lineWidth: 2
                            )
                    )
            }
            Spacer()
        }.padding()
    }
}
