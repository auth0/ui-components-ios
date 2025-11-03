import SwiftUI

struct EmailPhoneEnrollmentView: View {
    @ObservedObject var viewModel: EmailPhoneEnrollmentViewModel
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text(viewModel.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color("000000", bundle: ResourceBundle.default))
                .padding(.bottom, 8)

            Text("We will text you a verification code.")
                .font(.system(size: 16))
                .foregroundStyle(Color("606060", bundle: ResourceBundle.default))
                .padding(.bottom, 25)

            Text(viewModel.isPhoneAuthMethod ? "Phone number" : "Email")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                .padding(.bottom, 8)

            if viewModel.isPhoneAuthMethod {
                HStack(spacing: 8) {
                    Button(action: {
                        viewModel.isPickerVisible.toggle()
                    }) {
                        HStack {
                            Text(viewModel.selectedCountry?.countryFlag ?? "")
                                .frame(height: 20)
                            
                            Text(viewModel.selectedCountry?.countryCode ?? "")
                                .foregroundStyle(Color("1F1F1F", bundle: ResourceBundle.default))
                                .font(.system(size: 20, weight: .semibold))
                        }.padding(5)
                    }

                    Image("chevrondown", bundle: ResourceBundle.default)
                        .frame(width: 10, height: 5.5)
                    TextField("Phone Number", text: $viewModel.phoneNumber)
                    #if !os(macOS)
                        .keyboardType(.numberPad)
                    #endif
                        .focused($textFieldFocused)
                }.padding()
                    .frame(height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color("CECECE", bundle: ResourceBundle.default), lineWidth: 1)
                    }.padding(.bottom, 100)
            } else {
                TextField("Email", text: $viewModel.email)
                    .focused($textFieldFocused)
                    .padding()
                    .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color("CECECE", bundle: ResourceBundle.default), lineWidth: 1)
                        }.padding(.bottom, 100)
            }
            Button(action: {
                viewModel.startEnrollment()
            }, label: {
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
            })
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
        }.padding()
            .ignoresSafeArea(.keyboard)
            .navigationTitle(Text(viewModel.navigationTitle))
            .toolbar {
                #if !os(visionOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        textFieldFocused = false
                    }
                }
                #endif
            }
            .sheet(isPresented: $viewModel.isPickerVisible) {
                CountryPicker(country: $viewModel.selectedCountry)
            }.onAppear {
                textFieldFocused = true
            }.onDisappear {
                textFieldFocused = false
            }
    }
}
