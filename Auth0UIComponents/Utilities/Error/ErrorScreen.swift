//
//  ErrorScreen.swift
//  Auth0UIComponents
//
//  Created by Nandan Prabhu P on 14/10/25.
//

import SwiftUI

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
                    .font(.system(size: 14))
                    .foregroundStyle(Color("737373", bundle: ResourceBundle.default))

                Button {
                    viewModel.handleButtonClick()
                } label: {
                    Text(viewModel.buttonTitle)
                        .foregroundStyle(Color.white)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                }.frame(height: 48)
                    .background(Color("262420", bundle: ResourceBundle.default))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            Spacer()
        }.padding()
    }
}
