import SwiftUI

/// The blueprint for any brand integrating a Theme.
public protocol Theme {
    var colors: ColorTheme { get }
    var typography: TypographyTheme { get }
    var layout: LayoutTheme { get }
}
