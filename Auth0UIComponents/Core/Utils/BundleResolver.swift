import Foundation

private final class BundleToken {}

public enum ResourceBundle {
    nonisolated(unsafe) public static var `default`: Bundle = {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: BundleToken.self)
        #endif
    }()
}
