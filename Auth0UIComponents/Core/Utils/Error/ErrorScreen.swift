import SwiftUI

struct ErrorScreen: View {
    // MARK: - View Model
    let viewModel: ErrorScreenViewModel
    
    // MARK: - Theme
    @Environment(\.theme) var theme

    // MARK: - Main body
    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.title)
                    .textStyle(.title, theme: theme)
                
                Text(viewModel.subTitle)
                    .textStyle(.helper, theme: theme)
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
                    .themeButtonStyle(.primary)
                    .foregroundStyle(theme.colors.error)
            }
            Spacer()
        }.padding()
    }
}
