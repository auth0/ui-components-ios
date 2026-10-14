import SwiftUI

// iOS/visionOS-only modifiers; each returns `self` unchanged elsewhere.
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
