import SwiftUI

/// Either the standard screen for a slot, or the app's own view built from the slot's typed model.
///
/// A replaced screen only renders its model and calls its actions, so the flow's transitions, timers and retries
/// keep working.
public struct MfaScreenSlot<Model> {
    enum Source {
        case standard
        case custom((Model) -> AnyView)
    }

    let source: Source

    /// The SDK's own screen.
    public static var standard: Self { .init(source: .standard) }

    /// Your screen, built from the model the slot receives.
    public static func custom<Content: View>(_ build: @escaping (Model) -> Content) -> Self {
        .init(source: .custom { AnyView(build($0)) })
    }

    func view<Standard: View>(for model: Model, standard: () -> Standard) -> AnyView {
        switch source {
        case .standard: return AnyView(standard())
        case let .custom(build): return build(model)
        }
    }
}

/// The screens an app can replace. Leave a slot alone to keep the standard screen.
///
/// The Core owns the factor list and the error screen. A factor's own screen is replaced by factor id, and each
/// factor adds a typed shortcut with an extension (for example `pushChallenge:`), so the Core doesn't list factors.
public struct MfaScreens {
    /// The screen that lists the factors to choose from.
    public var authenticatorList: MfaScreenSlot<AuthenticatorListModel> = .standard
    /// The screen that says why the flow ended, with a way out.
    public var error: MfaScreenSlot<ErrorModel> = .standard
    /// Replacements for factor screens, by factor. Returns `nil` for a model it doesn't recognise.
    var factorViews: [MfaFactorID: (any MfaFactorModel) -> AnyView?] = [:]

    /// Creates a set of screens that keeps the standard ones.
    ///
    /// - Parameters:
    ///   - authenticatorList: The factor list screen.
    ///   - error: The error screen.
    public init(authenticatorList: MfaScreenSlot<AuthenticatorListModel> = .standard,
                error: MfaScreenSlot<ErrorModel> = .standard) {
        self.authenticatorList = authenticatorList
        self.error = error
    }

    /// A copy that draws `factor`'s screen with `build`. The model type is the one the factor defines.
    public func replacing<Model: MfaFactorModel, Content: View>(
        _ factor: MfaFactorID, with build: @escaping (Model) -> Content) -> MfaScreens {
        var copy = self
        copy.factorViews[factor] = { ($0 as? Model).map { AnyView(build($0)) } }
        return copy
    }
}

/// Who draws the flow.
public enum MfaPresentation {
    /// The SDK renders every step.
    case standard
    /// Nothing is rendered. The flow publishes each `MfaStep` into the stream, and the app draws them and calls the
    /// model's actions.
    case headless(MfaStepStream)
}

/// How an MFA flow looks. The default needs no configuration.
public struct MfaConfiguration {
    /// The words on every MFA screen. Override any of them; the rest keep their defaults.
    public var messages: MfaMessages
    /// The screens you replaced. Everything else uses the standard screens.
    public var screens: MfaScreens
    /// Who draws the flow: the SDK, or your app.
    public var presentation: MfaPresentation
    /// How many steps a sign-in may take. Each time the server asks for another factor, the flow starts a new round
    /// with a fresh list; one more than this ends the flow with ``MfaError/maxChallengesExceeded``. The default, 3,
    /// is what the specification sets.
    public var maximumRounds: Int

    /// The number of steps the specification allows by default.
    public static let defaultMaximumRounds = 3

    /// Creates a configuration. Every parameter is optional, and the defaults need no setup.
    ///
    /// - Parameters:
    ///   - messages: The words on every screen.
    ///   - screens: The screens you replace.
    ///   - presentation: Who draws the flow.
    ///   - maximumRounds: How many steps a sign-in may take.
    public init(messages: MfaMessages = .default, screens: MfaScreens = MfaScreens(),
                presentation: MfaPresentation = .standard, maximumRounds: Int = MfaConfiguration.defaultMaximumRounds) {
        self.messages = messages
        self.screens = screens
        self.presentation = presentation
        self.maximumRounds = maximumRounds
    }
}
