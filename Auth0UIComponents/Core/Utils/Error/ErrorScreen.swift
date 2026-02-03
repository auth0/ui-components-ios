import SwiftUI

/// Displays an error message screen to the user.
///
/// This view presents an error state with a title, detailed message, and an action button.
/// It is used throughout Auth0 UI Components to display error states from failed operations.
struct ErrorScreen: View {
    /// The view model providing error information and callbacks
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
