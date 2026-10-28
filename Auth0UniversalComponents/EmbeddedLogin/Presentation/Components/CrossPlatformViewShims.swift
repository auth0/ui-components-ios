import SwiftUI

// Platform-specific modifiers; each falls back to a working equivalent elsewhere.
extension View {
    /// Hides the system bar and back button so `LoginNavigationBar` can stand in.
    @ViewBuilder
    func systemNavigationBarHidden() -> some View {
        #if os(iOS) || os(visionOS)
        self.navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        #else
        self.navigationBarBackButtonHidden(true)
        #endif
    }

    @ViewBuilder
    func onChangeCompat<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        #if os(visionOS)
        onChange(of: value) { _, newValue in action(newValue) }
        #else
        if #available(iOS 17, macOS 14, *) {
            onChange(of: value) { _, newValue in action(newValue) }
        } else {
            onChange(of: value, perform: action)
        }
        #endif
    }

    /// Email keyboard, no autocorrect or autocapitalization.
    @ViewBuilder
    func emailInput() -> some View {
        #if os(iOS) || os(visionOS)
        self.keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
        #else
        self
        #endif
    }
}
