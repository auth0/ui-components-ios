import Auth0
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Auth0UniversalComponents

/// The server's offer of sign-up, from the SDK's answer to the first screen's link.
@MainActor
@Suite struct LoginSignupOfferTests {

    private typealias Fixtures = EmbeddedAuthFixtures

    @Test func theServerOfferingSignup_isReadFromItsFirstAnswer() async throws {
        let client = StubEmbeddedAuthClient()
        client.authorizeResults = [Fixtures.needs([Fixtures.identifyEmail, Fixtures.signup()])]
        let sut = Auth0EmbeddedAuthInteractor(client: client, credentialsDelivery: StubCredentialsDelivery(),
                                              connection: "db")

        let options = try await sut.discover()

        #expect(options == [.emailOTP(connection: "db"), .signup])
    }

    @Test func theCoordinator_offersSignup_onlyWhenTheServerDid() async {
        let offered = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(
            discover: .success([.emailOTP(connection: "db"), .signup])))
        let notOffered = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(
            discover: .success([.emailOTP(connection: "db")])))

        await offered.send(.start)
        await notOffered.send(.start)

        #expect(offered.canSignUp)
        #expect(!notOffered.canSignUp)
        #expect(offered.step == .collectOTPIdentifier(.email), "sign-up is not a way to sign in")
    }

    @Test func aTenantWithOnlySignup_hasNoWayToSignIn() async {
        let sut = LoginFlowCoordinator(interactor: ScriptedAuthInteractor(discover: .success([.signup])))
        await sut.send(.start)
        #expect(sut.step == .noMethodsAvailable)
    }

    @Test func theLogin_tellsTheServerItCanSendTheUserToSignup_onlyWhenTheAppOffersIt() {
        let base = LiveEmbeddedAuthClient.capabilities(adding: [])
        let offered = LiveEmbeddedAuthClient.capabilities(adding: LiveEmbeddedAuthClient.signupCapabilities)

        #expect(!base.contains(.signup) && !base.contains(.confirmSignup))
        #expect(offered == base + [.signup, .confirmSignup])
    }
}

/// The entry screen is built from pieces a brand can place, and the default places them as the designs do.
@MainActor
@Suite struct EmbeddedEntryCompositionTests {

    /// What the layout was given the last time the screen was drawn.
    private final class Seen {
        var parts: [EmbeddedEntryParts] = []
    }

    /// Draws the view, which is what runs the layout.
    private func draw<V: View>(_ view: V) {
        let renderer = ImageRenderer(content: view.frame(width: 390, height: 800))
        _ = renderer.cgImage
    }

    private func recordingLayout(_ seen: Seen) -> EmbeddedEntryLayout {
        EmbeddedEntryLayout { parts in
            seen.parts.append(parts)
            return Text("custom layout")
        }
    }

    @Test func aBrandsLayout_getsTheLogo_theTitle_theForm_andTheLink() {
        let seen = Seen()
        draw(LoginIdentifierScreen(channel: .email, alternatives: [], accountLink: .signUp, onContinue: { _ in })
            .embeddedEntryLogo { Image(systemName: "shield") }
            .embeddedEntryLayout(recordingLayout(seen)))

        let parts = seen.parts.last
        #expect(parts != nil)
        #expect(parts?.logo != nil)
        #expect(parts?.accountLink != nil)
        #expect(parts?.alternatives == nil, "one way to sign in: no \"OR\"")
    }

    @Test func theLogoIsTheThemes_unlessTheAppHidesIt() {
        let seen = Seen()
        draw(LoginIdentifierScreen(channel: .email, alternatives: [], onContinue: { _ in })
            .embeddedEntryLayout(recordingLayout(seen)))
        #expect(seen.parts.last?.logo != nil, "Auth0's logo is there with nothing set")

        let hidden = Seen()
        draw(LoginIdentifierScreen(channel: .email, alternatives: [], onContinue: { _ in })
            .embeddedEntryLogo(.hidden)
            .embeddedEntryLayout(recordingLayout(hidden)))
        #expect(hidden.parts.last?.logo == nil)
    }

    @Test func aThemeWithItsOwnBrand_stillDrawsTheLogo() {
        let seen = Seen()
        var theme = Auth0Theme()
        theme.brand = DefaultAuth0BrandTokens(logo: Image(systemName: "star"), logoLabel: "Acme")
        draw(LoginIdentifierScreen(channel: .email, alternatives: [], onContinue: { _ in })
            .auth0Theme(theme)
            .embeddedEntryLayout(recordingLayout(seen)))

        #expect(seen.parts.last?.logo != nil)
    }

    @Test func withoutALinkOrOtherWays_thoseAreLeftOut() {
        let seen = Seen()
        draw(LoginIdentifierScreen(channel: .email, alternatives: [], onContinue: { _ in })
            .embeddedEntryLayout(recordingLayout(seen)))

        #expect(seen.parts.last?.accountLink == nil)
        #expect(seen.parts.last?.alternatives == nil)
    }

    @Test func otherWays_arePassedAsAPiece() {
        let seen = Seen()
        draw(LoginIdentifierScreen(channel: .email, alternatives: [.phone], onContinue: { _ in })
            .embeddedEntryLayout(recordingLayout(seen)))

        #expect(seen.parts.last?.alternatives != nil)
    }

    @Test func theSignupEntry_isTheSameScreen_withItsOwnTitleAndLink() {
        let seen = Seen()
        draw(LoginIdentifierScreen(channel: .email, alternatives: [], title: "Create your account",
                                   accountLink: .logIn, onContinue: { _ in })
            .embeddedEntryLayout(recordingLayout(seen)))

        #expect(seen.parts.last?.accountLink != nil)
    }

    @Test func theDefaultLayouts_drawTheEntryScreen() {
        // Both presets lay the same pieces out; this fails if one of them can't be drawn at all.
        for layout in [EmbeddedEntryLayout.centered, .top] {
            let renderer = ImageRenderer(content: LoginIdentifierScreen(channel: .email, alternatives: [.phone],
                                                                        accountLink: .signUp, onContinue: { _ in })
                .embeddedEntryLayout(layout).frame(width: 390, height: 800))
            #expect(renderer.cgImage != nil)
        }
    }

    @Test func theWords_haveTheDesignsDefaults_andCanBeReplaced() {
        let messages = EmbeddedEntryMessages()
        #expect(messages.loginOrSignUpTitle == "Log in or sign up")
        #expect(messages.signUpTitle == "Create your account")
        #expect(messages.signUpAction == "Sign up" && messages.logInAction == "Log in")
        #expect(messages.loginTitle == nil, "the login keeps the way's own title unless a brand sets one")

        #expect(EmbeddedEntryMessages(signUpTitle: "Join us").signUpTitle == "Join us")
    }
}

/// The brand's foreground colours are design-system tokens, readable in both appearances, and a theme written before
/// them still compiles.
@MainActor
@Suite struct ForegroundColorTokenTests {

    private struct OlderTheme: Auth0ColorTokens {
        var background: any Auth0BackgroundColorTokens { DefaultAuth0BackgroundColorTokens() }
        var text: any Auth0TextColorTokens { DefaultAuth0TextColorTokens() }
        var border: any Auth0BorderColorTokens { DefaultAuth0BorderColorTokens() }
    }

    #if canImport(UIKit)
    private func hex(_ color: SwiftUI.Color, dark: Bool) -> String {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()),
                      Int((blue * 255).rounded()))
    }

    /// WCAG relative luminance of a `#RRGGBB` string.
    private func luminance(_ hex: String) -> Double {
        let channels = stride(from: 1, to: 7, by: 2).map { offset -> Double in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            let value = Double(Int(hex[start..<hex.index(start, offsetBy: 2)], radix: 16) ?? 0) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }

    private func contrast(_ foreground: String, _ background: String) -> Double {
        let lighter = max(luminance(foreground), luminance(background))
        let darker = min(luminance(foreground), luminance(background))
        return (lighter + 0.05) / (darker + 0.05)
    }

    @Test func linkPrimary_isThePurpleOfTheDesigns_andLighterInDarkMode() {
        let link = DefaultAuth0ColorTokens().foreground.linkPrimary
        #expect(hex(link, dark: false) == "#9921FE")
        #expect(hex(link, dark: true) == "#B570FF")
    }

    @Test func error_isTheRedOfTheDesigns_andLighterInDarkMode() {
        let error = DefaultAuth0ColorTokens().foreground.error
        #expect(hex(error, dark: false) == "#CA3B2B")
        #expect(hex(error, dark: true) == "#EF6B5E")
    }

    /// Small text needs 4.5:1 (WCAG AA) against the screen's background, in both appearances.
    @Test func linkAndErrorText_areReadableOnTheScreenBackground_inBothAppearances() {
        let colors = DefaultAuth0ColorTokens()
        let base = colors.background.layerBase
        for (name, token) in [("linkPrimary", colors.foreground.linkPrimary), ("error", colors.foreground.error)] {
            for dark in [false, true] {
                let ratio = contrast(hex(token, dark: dark), hex(base, dark: dark))
                #expect(ratio >= 4.5, "\(name) is \(ratio):1 in \(dark ? "dark" : "light") mode")
            }
        }
    }

    @Test func success_isTheGreenOfTheVerifiedScreen() {
        let success = DefaultAuth0ColorTokens().foreground.success
        #expect(hex(success, dark: false) == "#218C4D")
        #expect(hex(success, dark: true) == "#34D399")
    }

    @Test func aThemeWithoutForegroundTokens_getsTheDefault() {
        #expect(hex(OlderTheme().foreground.linkPrimary, dark: false) == "#9921FE")
    }
    #endif

    @Test func aBrand_canReplaceIt() {
        let colors = DefaultAuth0ColorTokens(foreground: DefaultAuth0ForegroundColorTokens(linkPrimary: .red))
        #expect(colors.foreground.linkPrimary == .red)
    }
}
