import SwiftUI
import Auth0UniversalComponents

enum ThemeOption: String, CaseIterable, Identifiable, Equatable {
    case automatic = "Automatic"
    case light = "Light"
    case dark = "Dark"
    case olive = "Custom Theme (Olive)"
    case purple = "Custom Theme (Purple)"

    var id: String { rawValue }
    var title: String { rawValue }

    var theme: Auth0Theme {
        switch self {

        case .automatic:
            return Auth0Theme()

        case .light:
            return Auth0Theme(
                colors: DefaultAuth0ColorTokens(
                    background: DefaultAuth0BackgroundColorTokens(
                        primary:       Color(red: 0.035, green: 0.035, blue: 0.043),          // #09090B
                        primarySubtle: Color(red: 0.035, green: 0.035, blue: 0.043).opacity(0.35),
                        inverse:       Color(red: 0.094, green: 0.094, blue: 0.106),          // #18181B
                        accent:        Color(red: 0.035, green: 0.035, blue: 0.043),          // #09090B
                        layerTop:      .white,                                                 // #FFFFFF
                        layerMedium:   Color(red: 0.988, green: 0.988, blue: 0.988),          // #FCFCFC
                        layerBase:     Color(red: 0.957, green: 0.957, blue: 0.961),          // #F4F4F5
                        error:         Color(red: 0.996, green: 0.886, blue: 0.886),          // #FEE2E2
                        errorSubtle:   Color(red: 0.996, green: 0.949, blue: 0.949),          // #FEF2F2
                        success:       Color(red: 0.902, green: 0.969, blue: 0.918),          // #E6F7EA
                        successSubtle: Color(red: 0.980, green: 0.996, blue: 0.984)           // #FAFEFB
                    ),
                    text: DefaultAuth0TextColorTokens(
                        bold:      Color(red: 0.122, green: 0.122, blue: 0.122),              // #1F1F1F
                        regular:   Color(red: 0.388, green: 0.388, blue: 0.388),              // #636363
                        disabled:  Color(red: 0.557, green: 0.557, blue: 0.557),              // #8E8E8E
                        onPrimary: Color(red: 0.941, green: 0.941, blue: 0.941),              // #F0F0F0
                        onSuccess: Color(red: 0.431, green: 0.906, blue: 0.718),              // #6EE7B7
                        onError:   Color(red: 0.600, green: 0.106, blue: 0.106)               // #991B1B
                    ),
                    border: DefaultAuth0BorderColorTokens(
                        bold:    Color(red: 0.631, green: 0.631, blue: 0.667),                // #A1A1AA
                        regular: Color(red: 0.851, green: 0.851, blue: 0.851),                // #D9D9D9
                        subtle:  Color(red: 0.894, green: 0.894, blue: 0.906),                // #E4E4E7
                        shadow:  Color(red: 0.808, green: 0.808, blue: 0.808).opacity(0.50)   // #CECECE @50%
                    )
                )
            )

        case .dark:
            return Auth0Theme(
                colors: DefaultAuth0ColorTokens(
                    background: DefaultAuth0BackgroundColorTokens(
                        primary:       Color(red: 0.980, green: 0.980, blue: 0.980),          // #FAFAFA
                        primarySubtle: Color(red: 0.980, green: 0.980, blue: 0.980).opacity(0.50),
                        inverse:       Color(red: 0.980, green: 0.980, blue: 0.980),          // #FAFAFA
                        accent:        Color(red: 0.655, green: 0.953, blue: 0.816),          // #A7F3D0
                        layerTop:      Color(red: 0.247, green: 0.247, blue: 0.275),          // #3F3F46
                        layerMedium:   Color(red: 0.153, green: 0.153, blue: 0.165),          // #27272A
                        layerBase:     Color(red: 0.035, green: 0.035, blue: 0.043),          // #09090B
                        error:         Color(red: 0.992, green: 0.643, blue: 0.686),          // #FDA4AF
                        errorSubtle:   Color(red: 0.745, green: 0.071, blue: 0.235),          // #BE123C
                        success:       Color(red: 0.655, green: 0.953, blue: 0.816),          // #A7F3D0
                        successSubtle: Color(red: 0.020, green: 0.588, blue: 0.412)           // #059669
                    ),
                    text: DefaultAuth0TextColorTokens(
                        bold:      Color(red: 0.980, green: 0.980, blue: 0.980),              // #FAFAFA
                        regular:   Color(red: 0.631, green: 0.631, blue: 0.667),              // #A1A1AA
                        disabled:  Color(red: 0.322, green: 0.322, blue: 0.357),              // #52525B
                        onPrimary: Color(red: 0.094, green: 0.094, blue: 0.106),              // #18181B
                        onSuccess: Color(red: 0.655, green: 0.953, blue: 0.816),              // #A7F3D0
                        onError:   Color(red: 1.000, green: 0.812, blue: 0.769)               // #FFCFC5
                    ),
                    border: DefaultAuth0BorderColorTokens(
                        bold:    Color(red: 0.443, green: 0.443, blue: 0.478),                // #71717A
                        regular: Color(red: 0.247, green: 0.247, blue: 0.275),                // #3F3F46
                        subtle:  .clear,
                        shadow:  Color(red: 0.247, green: 0.247, blue: 0.275)                 // #3F3F46
                    )
                )
            )

        case .olive:
            return Auth0Theme(
                colors: DefaultAuth0ColorTokens(
                    background: DefaultAuth0BackgroundColorTokens(
                        primary:       Color(red: 0.251, green: 0.369, blue: 0.071),          // #405E12
                        primarySubtle: Color(red: 0.251, green: 0.369, blue: 0.071).opacity(0.12),
                        inverse:       Color(red: 0.110, green: 0.169, blue: 0.016),          // #1C2B04
                        accent:        Color(red: 0.831, green: 0.910, blue: 0.659),          // #D4E8A8
                        layerTop:      .white,
                        layerMedium:   Color(red: 0.973, green: 0.980, blue: 0.949),          // #F8FAF2
                        layerBase:     Color(red: 0.949, green: 0.961, blue: 0.910),          // #F2F5E8
                        error:         Color(red: 0.996, green: 0.886, blue: 0.886),          // #FEE2E2
                        errorSubtle:   Color(red: 0.996, green: 0.949, blue: 0.949),          // #FEF2F2
                        success:       Color(red: 0.902, green: 0.969, blue: 0.918),          // #E6F7EA
                        successSubtle: Color(red: 0.980, green: 0.996, blue: 0.984)           // #FAFEFB
                    ),
                    text: DefaultAuth0TextColorTokens(
                        bold:      Color(red: 0.110, green: 0.169, blue: 0.016),              // #1C2B04
                        regular:   Color(red: 0.290, green: 0.361, blue: 0.165),              // #4A5C2A
                        disabled:  Color(red: 0.557, green: 0.612, blue: 0.431),              // #8E9C6E
                        onPrimary: Color(red: 0.980, green: 1.000, blue: 0.949),              // #FAFFF2
                        onSuccess: Color(red: 0.431, green: 0.906, blue: 0.718),              // #6EE7B7
                        onError:   Color(red: 0.600, green: 0.106, blue: 0.106)               // #991B1B
                    ),
                    border: DefaultAuth0BorderColorTokens(
                        bold:    Color(red: 0.361, green: 0.478, blue: 0.157),                // #5C7A28
                        regular: Color(red: 0.784, green: 0.851, blue: 0.627),                // #C8D9A0
                        subtle:  Color(red: 0.890, green: 0.925, blue: 0.784),                // #E3ECC8
                        shadow:  Color.black.opacity(0.07)
                    )
                )
            )

        case .purple:
            return Auth0Theme(
                colors: DefaultAuth0ColorTokens(
                    background: DefaultAuth0BackgroundColorTokens(
                        primary:       Color(red: 0.357, green: 0.129, blue: 0.714),          // #5B21B6
                        primarySubtle: Color(red: 0.357, green: 0.129, blue: 0.714).opacity(0.12),
                        inverse:       Color(red: 0.114, green: 0.063, blue: 0.251),          // #1D1040
                        accent:        Color(red: 0.929, green: 0.914, blue: 0.996),          // #EDE9FE
                        layerTop:      .white,
                        layerMedium:   Color(red: 0.980, green: 0.976, blue: 1.000),          // #FAF9FF
                        layerBase:     Color(red: 0.961, green: 0.953, blue: 1.000),          // #F5F3FF
                        error:         Color(red: 0.996, green: 0.886, blue: 0.886),          // #FEE2E2
                        errorSubtle:   Color(red: 0.996, green: 0.949, blue: 0.949),          // #FEF2F2
                        success:       Color(red: 0.902, green: 0.969, blue: 0.918),          // #E6F7EA
                        successSubtle: Color(red: 0.980, green: 0.996, blue: 0.984)           // #FAFEFB
                    ),
                    text: DefaultAuth0TextColorTokens(
                        bold:      Color(red: 0.110, green: 0.063, blue: 0.251),              // #1C1040
                        regular:   Color(red: 0.357, green: 0.294, blue: 0.541),              // #5B4B8A
                        disabled:  Color(red: 0.608, green: 0.545, blue: 0.722),              // #9B8BB8
                        onPrimary: Color(red: 0.961, green: 0.953, blue: 1.000),              // #F5F3FF
                        onSuccess: Color(red: 0.431, green: 0.906, blue: 0.718),              // #6EE7B7
                        onError:   Color(red: 0.600, green: 0.106, blue: 0.106)               // #991B1B
                    ),
                    border: DefaultAuth0BorderColorTokens(
                        bold:    Color(red: 0.486, green: 0.227, blue: 0.929),                // #7C3AED
                        regular: Color(red: 0.867, green: 0.839, blue: 0.996),                // #DDD6FE
                        subtle:  Color(red: 0.929, green: 0.914, blue: 0.996),                // #EDE9FE
                        shadow:  Color.black.opacity(0.07)
                    )
                )
            )
        }
    }
}
