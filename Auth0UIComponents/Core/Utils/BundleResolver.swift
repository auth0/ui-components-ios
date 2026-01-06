import Foundation

private final class BundleToken {}

public enum ResourceBundle {
    /// The bundle where resources live for this module (SPM or framework)
    nonisolated(unsafe) public static var `default`: Bundle = {
        #if SWIFT_PACKAGE
        // When compiled by SwiftPM, Bundle.module is available
        return .module
        #else
        // When compiled as a framework/library in Xcode, locate bundle via a token class
        return Bundle(for: BundleToken.self)
        #endif
    }()
}
