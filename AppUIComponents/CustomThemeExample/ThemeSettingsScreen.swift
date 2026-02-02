import SwiftUI
import Auth0UIComponents

struct ThemeSettingsView: View {
    // MARK: - Properties
    // SDK's theme engine
    @EnvironmentObject var manager: ThemeManager
    // To manually 'Dismiss' the screen
    @Environment(\.dismiss) private var dismiss
    
    // Local state to track the picker's selection
    // We initialize this based on the current theme's type
    @State private var selectedTab: LocalThemeOption = .defaultTheme

    var body: some View {
        VStack {
            List {
                Section(header: Text("UI Customization")) {
                    Picker("Theme", selection: $selectedTab) {
                        ForEach(LocalThemeOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Live Preview")) {
                    ThemePreviewCard(themeOption: $selectedTab)
                }
            }
            
            Spacer()
            
            Button {
                // Directly update the manager with the new instance
                withAnimation(.spring()) {
                    manager.current = selectedTab.instance
                    dismiss()
                }
            } label: {
                Text("Continue")
                    .foregroundStyle(AnyShapeStyle(Color.white))
                    .textStyle(.label, theme: selectedTab.instance)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .themeButtonStyle(.primary, theme: selectedTab.instance)
        }
        .onAppear {
            // Sync local state if the theme was changed elsewhere
            syncLocalState()
        }
    }
    
    private func syncLocalState() {
        if manager.current is DefaultTheme { selectedTab = .defaultTheme }
        else if manager.current is FloTheme { selectedTab = .floTheme }
        else if manager.current is GrandVisionTheme { selectedTab = .grandVisionTheme }
    }
}

// Isolated enum only used for this specific UI
internal enum LocalThemeOption: String, CaseIterable {
    case defaultTheme = "Default"
    case floTheme = "Flo"
    case grandVisionTheme = "Grand Vision"
    
    var instance: Theme {
        switch self {
        case .defaultTheme: return DefaultTheme()
        case .floTheme: return FloTheme()
        case .grandVisionTheme: return GrandVisionTheme()
        }
    }
}
