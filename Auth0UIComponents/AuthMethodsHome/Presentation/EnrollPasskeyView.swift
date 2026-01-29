import SwiftUI

@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct EnrollPasskeyView: View {
    var viewModel: PasskeysEnrollmentViewModel
    var body: some View {
        VStack {
            Text("With Passkey, you don’t have to remember complext passwords.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What are passkeys?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                    Text(" Passkeys are encrypted digital keys you create using your fingerprint, face, or screen lock.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                }
                Spacer()
            }.padding(.top, 24)
  
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Where are passkeys saved?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                    Text("Passkeys are saved in your credential manager, so you can sign in on other devices.")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                }
                Spacer()
            }.padding(.top, 24)

            Button {
                Task {
                    await viewModel.startEnrollment()
                }
            } label: {
                Label {
                    Text("Add a Passkey")
                        .font(.system(size: 16).weight(.medium))
                        .foregroundStyle(Color("262420", bundle: ResourceBundle.default))
                } icon: {
                    Image("passkey", bundle: ResourceBundle.default)
                }.frame(maxWidth: .infinity)
            }.frame(height: 48)
                .background(
                    LinearGradient(
                        stops: [
                            Gradient.Stop(color: Color("262420", bundle: ResourceBundle.default), location: 0.00),
                            Gradient.Stop(color: Color("262420", bundle: ResourceBundle.default).opacity(0.05), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .background(Color("FFFFFF", bundle: ResourceBundle.default))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color("000000", bundle: ResourceBundle.default).opacity(0.10), radius: 4, x: 0, y: 4)
                .shadow(color: Color("000000", bundle: ResourceBundle.default).opacity(0.10), radius: 2, x: 0, y: 2)
                .shadow(color: Color("000000", bundle: ResourceBundle.default).opacity(0.10), radius: 0.5, x: 0, y: 1)
                .shadow(color: Color("000000", bundle: ResourceBundle.default).opacity(0.10), radius: 1, x: 0, y: 2)
                .shadow(color: Color("000000", bundle: ResourceBundle.default).opacity(0.05), radius: 0, x: 0, y: 0)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .inset(by: 0.5)
                        .stroke(Color("262420", bundle: ResourceBundle.default).opacity(0.35), lineWidth: 1)
                )
                .padding(.top, 16)

            Text("Remind me later")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("262420", bundle: ResourceBundle.default))
                .padding(EdgeInsets(top: 20, leading: 0, bottom: 32, trailing: 0))

        }.padding(.all, 20).background(Color("F0F0F0", bundle: ResourceBundle.default).opacity(0.90)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
