import SwiftUI

/// One-box-per-digit code entry. `isError` switches to the rejected-code treatment. While `isEnabled` is off (a verify
/// is in flight) the digits grey out, taps are ignored and the keyboard goes away.
public struct LoginCodeField: View {
    @Binding var code: String
    let digitCount: Int
    let isError: Bool
    let isEnabled: Bool

    @Environment(\.auth0Theme) private var theme
    @FocusState private var focusedField: Int?

    public init(code: Binding<String>, digitCount: Int = 6, isError: Bool = false, isEnabled: Bool = true) {
        self._code = code
        self.digitCount = digitCount
        self.isError = isError
        self.isEnabled = isEnabled
    }

    public var body: some View {
        HStack(spacing: theme.spacing.xs) {
            ForEach(0..<digitCount, id: \.self) { digitBox($0) }
        }
        .allowsHitTesting(isEnabled)
        .onAppear { focusedField = 0 }
        // Back on the next box to fill (the last one when it's full), so a rejected code can be fixed at once.
        .onChangeCompat(of: isEnabled) { focusedField = $0 ? min(code.count, digitCount - 1) : nil }
    }

    private var digitColor: Color {
        if isError { return theme.colors.loginError }
        return isEnabled ? theme.colors.text.bold : theme.colors.text.disabled
    }

    private func digitBox(_ index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
        let isFocused = focusedField == index
        return OTPTextField(
            fullText: $code,
            index: index,
            digitCount: digitCount,
            cursorTintColor: isError ? theme.colors.loginError : theme.colors.background.primary,
            setText: { setText($0, at: index) },
            enterKeyPressed: { focusedField = nil },
            emptyBackspaceKeyPressed: emptyBackspace,
            textColor: digitColor
        )
        .frame(maxWidth: .infinity)
        .frame(height: theme.sizes.size3xlDimen)
        .background(isError ? theme.colors.background.errorSubtle : theme.colors.background.layerTop, in: shape)
        .overlay(shape.strokeBorder(isError ? theme.colors.errorBorder : theme.colors.border.shadow, lineWidth: 1))
        .overlay {
            if isFocused && !isError {
                shape.strokeBorder(theme.colors.border.subtle, lineWidth: 3)
            }
        }
        .errorRing(isError && isFocused, cornerRadius: theme.radius.medium, color: theme.colors.errorRing)
        .shadow(color: .black.opacity(isError ? 0 : 0.07), radius: 4, x: 0, y: 2)
        .focused($focusedField, equals: index)
    }

    // Mirrors `OTPView.setTextAtIndex` — keeps focus advancing between digits.
    private func setText(_ string: String, at index: Int) {
        let old = code
        let strBefore = old.prefix(length: index)
        let suffixLength = old.count - index - (string.isEmpty ? 1 : string.count)
        let strAfter = suffixLength <= 0 ? "" : old.suffix(length: suffixLength)
        let new = (strBefore + string + strAfter).prefix(length: digitCount)
        code = new

        guard let focusedField else { return }

        if focusedField <= old.count - 1 {
            let newFocus = focusedField + (string.isEmpty ? -1 : string.count)
            self.focusedField = newFocus >= digitCount ? nil : newFocus
            return
        }

        let newFocus = new.count
        self.focusedField = newFocus >= digitCount ? nil : newFocus
    }

    private func emptyBackspace() {
        guard let focusedField, focusedField > 0 else { return }
        self.focusedField = focusedField - 1
    }
}
