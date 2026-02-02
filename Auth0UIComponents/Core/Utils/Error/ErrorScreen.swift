import SwiftUI

/// SwiftUI view displaying an error message with title, description, and action button.
struct ErrorScreen: View {
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
