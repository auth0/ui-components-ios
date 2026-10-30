import Combine
import Foundation

/// What a control on a screen does. It never affects equality, so steps stay `Equatable` and tests can compare them.
public struct MfaAction<Input>: Equatable {
    private let perform: (Input) -> Void

    /// Creates an action.
    ///
    /// - Parameter perform: What the control does.
    public init(_ perform: @escaping (Input) -> Void) {
        self.perform = perform
    }

    /// Performs the action.
    ///
    /// - Parameter input: The value the control passes along.
    public func callAsFunction(_ input: Input) {
        perform(input)
    }

    /// Two actions are always equal, so a step is equal whatever its closures do.
    public static func == (_: Self, _: Self) -> Bool { true }
}

extension MfaAction where Input == Void {
    /// Performs the action.
    public func callAsFunction() {
        perform(())
    }

    /// Does nothing. For previews and tests.
    public static var none: Self { MfaAction { _ in } }
}

/// The factor list. Shown with two or more eligible factors.
public struct AuthenticatorListModel: Equatable {
    /// Which heading the list shows.
    public enum Header: Equatable, Sendable {
        /// The first round.
        case challenge
        /// The server asked for another factor after a successful one: "One more step".
        case challengeAdditional
    }

    /// One factor on offer, already worded by the factor itself.
    public struct Row: Equatable, Identifiable {
        /// Identifies the row. Pass it to ``AuthenticatorListModel/select``.
        public let id: String
        /// The kind of factor the row stands for.
        public let factor: MfaFactorID
        /// What the row says, worded by its factor: usually a device name or a masked number.
        public let title: String
        /// A second line under the title, such as the kind of factor.
        public let subtitle: String?
        /// An image name in the SDK's resource bundle.
        public let icon: String?

        /// Creates a row.
        ///
        /// - Parameters:
        ///   - id: Identifies the row.
        ///   - factor: The kind of factor.
        ///   - title: What the row says.
        ///   - subtitle: A second line under the title.
        ///   - icon: An image name in the SDK's resource bundle.
        public init(id: String, factor: MfaFactorID, title: String, subtitle: String? = nil, icon: String? = nil) {
            self.id = id
            self.factor = factor
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
        }
    }

    /// Which heading the list shows.
    public let header: Header
    /// Which step of a multi-step sign-in this is, starting at 1. A policy that needs two factors shows this list
    /// twice, with 1 and then 2.
    public let round: Int
    /// The factors to choose from, best first.
    public let rows: [Row]
    /// The row whose challenge is being sent: show progress in place.
    public let pendingRowID: String?
    /// Chooses a row. Pass the row's ``AuthenticatorListModel/Row/id``.
    public let select: MfaAction<String>
    /// Ends the flow as cancelled.
    public let cancel: MfaAction<Void>

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - header: Which heading the list shows.
    ///   - round: Which step of the sign-in this is, starting at 1.
    ///   - rows: The factors to choose from.
    ///   - pendingRowID: The row whose challenge is being sent.
    ///   - select: Chooses a row.
    ///   - cancel: Ends the flow.
    public init(header: Header, round: Int = 1, rows: [Row], pendingRowID: String? = nil,
                select: MfaAction<String> = .init { _ in }, cancel: MfaAction<Void> = .none) {
        self.header = header
        self.round = round
        self.rows = rows
        self.pendingRowID = pendingRowID
        self.select = select
        self.cancel = cancel
    }
}

/// The loading step carries only a way out: `cancel` is nil when there is nothing to cancel (the flow is ending).
public struct LoadingModel: Equatable {
    /// Ends the flow, or `nil` when there is nothing left to cancel.
    public let cancel: MfaAction<Void>?

    /// Creates a model.
    ///
    /// - Parameter cancel: Ends the flow, or `nil` when it can no longer be cancelled.
    public init(cancel: MfaAction<Void>? = nil) {
        self.cancel = cancel
    }
}

/// How the error screen lets the user out: "Start over" in login, "Close" in a step-up sheet.
public enum MfaExit: Equatable, Sendable {
    /// Begins the sign-in again. Embedded Login uses this.
    case startOver
    /// Closes the sheet the flow runs in.
    case close
}

/// What the error screen shows.
public struct ErrorModel: Equatable {
    /// Why the flow ended.
    public let error: MfaError
    /// How the screen lets the user out.
    public let exit: MfaExit
    /// Takes the user out: starts the sign-in over, or closes the sheet, depending on ``ErrorModel/exit``.
    public let leave: MfaAction<Void>

    /// Creates a model.
    ///
    /// - Parameters:
    ///   - error: Why the flow ended.
    ///   - exit: How the screen lets the user out.
    ///   - leave: Takes the user out.
    public init(error: MfaError, exit: MfaExit = .startOver, leave: MfaAction<Void> = .none) {
        self.error = error
        self.exit = exit
        self.leave = leave
    }
}

/// A factor's own screen: whose it is, and the model that factor defined for it.
public struct MfaFactorStep: Equatable {
    /// The factor whose screen this is.
    public let factor: MfaFactorID
    /// What that factor's screen renders. Cast it to the factor's own model type, such as ``PushChallengeModel``.
    public let model: any MfaFactorModel
    /// Which step of a multi-step sign-in this is, starting at 1.
    public let round: Int

    /// Creates a step.
    ///
    /// - Parameters:
    ///   - factor: The factor whose screen this is.
    ///   - model: What that factor's screen renders.
    ///   - round: Which step of the sign-in this is, starting at 1.
    public init(factor: MfaFactorID, model: any MfaFactorModel, round: Int = 1) {
        self.factor = factor
        self.model = model
        self.round = round
    }

    /// Two steps are equal when they are the same factor's screen, in the same round, with equal models.
    public static func == (lhs: MfaFactorStep, rhs: MfaFactorStep) -> Bool {
        lhs.factor == rhs.factor && lhs.round == rhs.round && lhs.model.isEqual(to: rhs.model)
    }
}

/// What the flow is showing. The Core owns the factor list, the loading step and the error step; a factor's own screen
/// arrives as `.factor`, so a new factor adds no case here. Add `@unknown default` when switching.
public enum MfaStep: Equatable {
    /// Working, with nothing for the user to do but, sometimes, cancel.
    case loading(LoadingModel)
    /// The factors to choose from.
    case authenticatorList(AuthenticatorListModel)
    /// A factor's own screen, such as the push waiting screen. Cast its model to the factor's model type.
    case factor(MfaFactorStep)
    /// Why the flow ended, with a way out.
    case error(ErrorModel)
}

/// How a flow ended. The step stream alone can't tell "done" from "loading".
public enum MfaResult: Equatable, Sendable {
    /// The user is verified and the credentials are stored.
    case signedIn
    /// The flow ended without signing in, for this reason.
    case ended(MfaError)
}

/// Headless: the app owns a stream and reads `MfaStep`s from it; nothing is rendered for them.
///
/// Create it in the app, hand it to `MfaPresentation.headless`, and render `step` with your own views.
@MainActor
public final class MfaStepStream: ObservableObject {
    /// The step to render, or `nil` when there is nothing to draw: before a flow starts, and after one ends without
    /// a screen (signed in, cancelled, or no factor to use) or the user leaves its error screen.
    @Published public internal(set) var step: MfaStep?
    /// How the current flow ended, or `nil` while it runs. Cleared when the next flow starts: the login builds a new
    /// flow for each sign-in, and they all publish here.
    @Published public internal(set) var result: MfaResult?

    /// Creates a stream.
    public init() {}
}
