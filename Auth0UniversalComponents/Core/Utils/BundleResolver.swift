import Foundation

/// Token class used to locate the framework bundle in compiled frameworks.
///
/// This private class serves as a reference point for finding the bundle
/// that contains Auth0 UI Components resources (images, colors, etc.).
private final class BundleToken {}

/// Provides access to the Auth0 UI Components resource bundle.
///
/// This enum handles the differences between Swift Package Manager packages
/// and traditional iOS frameworks by providing a unified interface to the
/// bundle containing framework resources.
///
/// The bundle is used to load custom colors, images, and other resources
/// that are packaged with Auth0 UI Components.
///
/// Example:
/// ```swift
/// // Load a custom color from the resource bundle
/// let brandColor = Color("BrandColor", bundle: ResourceBundle.default)
///
/// // Load an image from the resource bundle
/// let logoImage = Image("Auth0Logo", bundle: ResourceBundle.default)
///
/// // Use in SwiftUI views
/// struct MyView: View {
///     var body: some View {
///         HStack {
///             logoImage
///             Text("Sign In")
///                 .foregroundColor(brandColor)
///         }
///     }
/// }
/// ```
public enum ResourceBundle {
    /// The default bundle containing Auth0 UI Components resources.
    ///
    /// In Swift Package Manager packages, this returns `.module`.
    /// In traditional frameworks, this returns the bundle containing the BundleToken class.
    nonisolated(unsafe) public static var `default`: Bundle = {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }()
}
