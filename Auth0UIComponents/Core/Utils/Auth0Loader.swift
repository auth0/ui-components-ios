import SwiftUI

/// Reusable circular progress indicator with customizable tint color
struct Auth0Loader: View {
    var tintColor: Color

    init(tintColor: Color = Color("3C3C43", bundle: ResourceBundle.default)) {
        self.tintColor = tintColor
    }

    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .tint(tintColor)
            .scaleEffect(1.5)
            .frame(width: 50, height: 50)
    }
}
