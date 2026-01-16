import SwiftUI

struct EmptyFactorsView: View {
    var body: some View {
        HStack {
            Image("info.circle.red", bundle: ResourceBundle.default)
                .frame(width: 16, height: 16)

            Text("No factors configured")
                .foregroundStyle(Color("CA3B2B", bundle: ResourceBundle.default))
                .font(.system(size: 14).weight(.medium))
            Spacer()
        }
        .padding(.all, 12)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color("D9D9D9", bundle: ResourceBundle.default), lineWidth: 1)
        }
    }
}

