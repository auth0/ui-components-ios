import SwiftUI

struct OTPView: View {
    @ObservedObject var viewModel: OTPViewModel
    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedField: Int?
    
    var body: some View {
        VStack(alignment: .leading) {
            if viewModel.isEmailOrSMS == false {
                Text("Enter the 6-digit code")
                    .font(Font.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                    .padding(.bottom, 8)
                
                Text("From your authenticator app")
                    .font(Font.system(size: 16))
                    .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                    .padding(.bottom, 76)
            } else {
                Text("Enter the 6 digit code we sent to \(viewModel.formattedEmailOrPhoneNumber)")
                    .multilineTextAlignment(.leading)
                    .font(Font.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                    .padding(.bottom, 30)
            }
            
            Text("One-Time Passcode")
                .font(Font.system(size: 16, weight: .medium))
                .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                .padding(.bottom, 16)
            
            otpTextFieldView()
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(Color("B82819", bundle: ResourceBundle.default))
                    .font(.system(size: 16))
                    .padding(EdgeInsets(top: 16, leading: 0, bottom: 100, trailing: 0))
            } else {
                if viewModel.isEmailOrSMS {
                    Text(attributedString())
                        .font(.system(size: 16))
                        .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                        .onTapGesture {
                            viewModel.restartEnrollment()
                        }.padding(EdgeInsets(top: 30, leading: 0, bottom: 100, trailing: 0))
                } else {
                    Spacer()
                }
            }
            Button {
                viewModel.confirmEnrollment(with: code)
            } label: {
                HStack {
                    Spacer()
                    if viewModel.apiCallInProgress {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(Color("FFFFFF", bundle: ResourceBundle.default))
                    } else {
                        Text("Continue")
                            .foregroundStyle(Color("FFFFFF", bundle: ResourceBundle.default))
                            .font(.system(size: 16, weight: .medium))
                    }
                    Spacer()
                }.frame(maxWidth: .infinity)
            }
            .frame(height: 48)
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
            Spacer()
        }.padding(EdgeInsets(top: 39, leading: 16, bottom: 40, trailing: 16))
            .ignoresSafeArea(.keyboard)
            .navigationTitle(viewModel.navigationTitle)
            .toolbar {
                #if !os(visionOS)
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            focusedField = nil
                        }
                    }
                #endif
            }
            .onAppear {
                focusedField = 0
            }
    }
    
    private func otpTextFieldView() -> some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                TextField("", text: $digits[index])
                    .font(.title)
                    .fontWeight(.semibold)
                    .frame(width: 50, height: 60)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .tint(Color.black)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(focusedField == index ? Color.black : Color.gray.opacity(0.5), lineWidth: 2)
                    )
                    .cornerRadius(8)
                    .focused($focusedField, equals: index)
                    .tag(index)
                    .onChange(of: digits[index]) { newValue in
                        handleInputChange(newValue: newValue, index: index)
                    }
            }
        }
    }

    private func handleInputChange(newValue: String, index: Int) {
        if !newValue.isEmpty {
            if index < digits.count - 1 {
                focusedField = index + 1
            }
        } else {
            if index > 0 {
                focusedField = index - 1
            }
        }
    }

    private var code: String {
        digits.joined()
    }

    func attributedString() -> AttributedString {
        var attributed = AttributedString("Didn’t get a code? Resend it.")
        if let range = attributed.range(of: "Resend it.") {
            attributed[range].foregroundColor = Color("000000", bundle: ResourceBundle.default)
            attributed[range].underlineStyle = .single
        }
        return attributed
    }
}
