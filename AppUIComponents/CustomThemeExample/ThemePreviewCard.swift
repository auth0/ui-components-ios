import SwiftUI
import Auth0UIComponents

struct ThemePreviewCard: View {
    // MARK: - Properties
    @Binding private var themeOption: LocalThemeOption
    
    private var theme: Theme { themeOption.instance }
    
    // MARK: - Init
    init(themeOption: Binding<LocalThemeOption>) {
        self._themeOption = themeOption
    }
    
    // MARK: - Main body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Text Roles
            VStack(alignment: .leading, spacing: 8) {
                Text("Typography Hierarchy")
                    .textStyle(.overline, theme: theme)
                Text("Display Headline")
                    .textStyle(.display, theme: theme)
                Text("This is how your body content looks. It's designed for readability and flow.")
                    .textStyle(.body, theme: theme)
            }
            
            Divider().background(theme.colors.border)
            
            // Icon & Status Roles
            HStack(spacing: 20) {
                VStack {
                    Image(systemName: "cpu")
//                        .themeIcon(.primary)
                        .font(.title)
                    Text("Primary")
                        .textStyle(.helper, theme: theme)
                }
                
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(theme.colors.error)
                        .font(.title)
                    Text("Error").textStyle(.helper, theme: theme)
                }
                
                VStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(theme.colors.success)
                        .font(.title)
                    Text("Success")
                        .textStyle(.helper, theme: theme)
                }
            }
            
            // Button Roles
            VStack(spacing: 12) {
                Button("Primary Action") {}
                    .themeButtonStyle(.primary, theme: theme)
                
                Button("Secondary Action") {}
                    .themeButtonStyle(.outline, theme: theme)
            }
        }
        .padding()
        .cornerRadius(theme.layout.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: theme.layout.cornerRadius)
                .stroke(theme.colors.border, lineWidth: 1)
        )
    }
}
