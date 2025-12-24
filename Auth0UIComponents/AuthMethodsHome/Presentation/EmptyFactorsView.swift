import SwiftUI

struct EmptyFactorsView: View {
    var body: some View {
        HStack {
            // Warning icon to draw attention
            Image("info.circle.red", bundle: ResourceBundle.default)
                .frame(width: 16, height: 16) // Fixed size for consistency

            // Clear, actionable message
            Text("No factors configured")
                .foregroundStyle(Color("CA3B2B", bundle: ResourceBundle.default)) // Red for alert/warning
                .font(.system(size: 14).weight(.medium)) // Medium weight for emphasis
            Spacer() // Pushes content to the left
        }
        .padding(.all, 12) // Internal spacing for comfortable readability
        .overlay {
            // Subtle border to define the warning area
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("D9D9D9", bundle: ResourceBundle.default), lineWidth: 1)
        }
    }
}

