import SwiftUI

struct ToastView: View {

  var style: ToastStyle
  var message: String
  var onCancelTapped: (() -> Void)
  
    var body: some View {
        Text(message)
            .font(Font.caption)
            .foregroundColor(style.messageColor)
            .padding()
            .background(style.toastBackgroundColor)
            .cornerRadius(8)
            .padding(.horizontal, 16)
    }
}
