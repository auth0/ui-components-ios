import Foundation

private final class BundleToken {}

/// Utility enum for accessing the resource bundle containing UI components assets.
public enum ResourceBundle {
    nonisolated(unsafe) public static var `default`: Bundle = {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }()
}
