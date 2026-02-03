import SwiftUI

/// A promotional banner view for passkey enrollment.
///
/// This view displays information about passkeys and encourages users to enroll
/// in passkey authentication. It includes educational content about what passkeys
/// are and where they are stored, along with an action button to start passkey enrollment.
///
/// Availability: Requires iOS 16.6, macOS 13.5, or visionOS 1.0+
@available(iOS 16.6, macOS 13.5, visionOS 1.0, *)
struct EnrollPasskeyView: View {
    /// Controls whether the passkey enrollment banner is displayed
    @Binding var collapsePasskeyBanner: Bool
    /// View model handling passkey enrollment logic
    var viewModel: PasskeysEnrollmentViewModel

    var body: some View {
        VStack {
            Text("With Passkey, you don’t have to remember complex passwords.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What are passkeys?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                    Text("Passkeys are encrypted digital keys you create using your fingerprint, face, or screen lock.")
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
                            Gradient.Stop(color: Color("262421", bundle: ResourceBundle.default).opacity(0), location: 0.00),
                            Gradient.Stop(color: Color("262421", bundle: ResourceBundle.default).opacity(0.05), location: 1.00),
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: UnitPoint(x: 0.5, y: 1)
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .inset(by: 0.5)
                        .stroke(Color("262420", bundle: ResourceBundle.default).opacity(0.35), lineWidth: 1)
                )
                .padding(.top, 16)

            Text("Remind me later")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color("262420", bundle: ResourceBundle.default))
                .onTapGesture {
                    withAnimation {
                        collapsePasskeyBanner.toggle()
                    }
                }
                .padding(EdgeInsets(top: 20, leading: 0, bottom: 32, trailing: 0))

        }.padding(.all, 20).background(Color("F0F0F0", bundle: ResourceBundle.default).opacity(0.90)).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
