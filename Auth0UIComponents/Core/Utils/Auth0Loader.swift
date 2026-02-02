import SwiftUI

/// A loading indicator view for Auth0 UI Components.
///
/// Displays a circular progress indicator with configurable tint color.
/// Used throughout Auth0 UI Components to indicate loading states during
/// authentication and API operations.
///
/// Example:
/// ```swift
/// Auth0Loader(tintColor: .blue)
/// ```
struct Auth0Loader: View {
    /// The color of the loading indicator
    var tintColor: Color

    /// Initializes the loader with an optional tint color.
    ///
    /// - Parameter tintColor: The color of the loading indicator (defaults to a dark gray)
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
