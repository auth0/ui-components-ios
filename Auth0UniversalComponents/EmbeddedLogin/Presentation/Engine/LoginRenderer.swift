import SwiftUI

// Maps a `LoginStep` to a `ScreenPlan` and builds its screen. Input goes back via `RenderContext`.

/// What a screen needs from the host, without knowing about the coordinator.
struct RenderContext {
    /// What the additional step shows; set while the coordinator is on `.additionalStep`.
    var additionalStepView: AnyView?
    /// Pre-fills the identifier screens, so Back from code entry keeps what the user typed.
    var identifier: LoginIdentifier?
    var isSubmitting: Bool
    var inputError: AuthFailure?
    let dispatch: (LoginEvent) -> Void
    let resend: () -> Void
    let back: () -> Void
}

enum ScreenPlan: Equatable {
    case loading
    /// Asks for `channel`. `alternatives` are the other ways listed under "OR"; only the first screen has them.
    /// `isFirst` is false on a way's own screen, opened from the first one.
    case identifier(LoginChannel, alternatives: [LoginChannel] = [], isFirst: Bool = true)
    case otpCode(identifier: LoginIdentifier, sentTo: String? = nil)
    case additionalStep
    case additionalStepUnavailable
    case authenticated
    case failed(message: String)
    case noMethods
}

extension ScreenPlan {
    /// Identifies the *screen*, ignoring inline payload, so payload changes don't transition.
    var transitionIdentity: String {
        switch self {
        case .loading:                   return "loading"
        case let .identifier(channel, _, _): return "identifier.\(channel)"
        case .otpCode:                   return "otpCode"
        case .additionalStep:            return "additionalStep"
        case .additionalStepUnavailable: return "additionalStepUnavailable"
        case .authenticated:             return "authenticated"
        case .failed:                    return "failed"
        case .noMethods:                 return "noMethods"
        }
    }

    /// Compared across a change to pick a push (deeper) or pop (shallower).
    var navigationDepth: Int {
        switch self {
        case .loading:                                    return 0
        case let .identifier(_, _, isFirst):              return isFirst ? 1 : 2
        case .noMethods:                                  return 1
        case .otpCode:                                    return 3
        case .additionalStep, .additionalStepUnavailable: return 4
        case .authenticated, .failed:                     return 5
        }
    }
}

struct LoginRenderer {

    /// - Parameter channels: The ways the tenant offers, in its order; the first is the starting screen.
    func plan(for step: LoginStep, channels: [LoginChannel] = []) -> ScreenPlan {
        switch step {
        case .loading:                    return .loading
        case let .collectOTPIdentifier(channel):
            let isFirst = channel == channels.first ?? channel
            return .identifier(channel, alternatives: isFirst ? channels.filter { $0 != channel } : [],
                               isFirst: isFirst)
        case let .collectOTPCode(identifier, sentTo): return .otpCode(identifier: identifier, sentTo: sentTo)
        case .additionalStep:             return .additionalStep
        case .additionalStepUnavailable:  return .additionalStepUnavailable
        case .authenticated:              return .authenticated
        case let .failed(message):        return .failed(message: message)
        case .noMethodsAvailable:         return .noMethods
        }
    }

    @ViewBuilder
    func view(for plan: ScreenPlan, context ctx: RenderContext) -> some View {
        switch plan {
        case .loading:
            LoginLoadingScreen()

        case let .identifier(channel, alternatives, _):
            identifierScreen(channel, alternatives: alternatives, context: ctx)

        case let .otpCode(identifier, sentTo):
            LoginCodeScreen(
                subtitle: "From \(sentTo ?? identifier.value)",
                isLoading: ctx.isSubmitting,
                errorMessage: ctx.inputError?.message(for: identifier.channel),
                isCodeExpired: ctx.inputError == .codeExpired,
                onVerify: { ctx.dispatch(.submitOTP(code: $0)) },
                onEdit: ctx.back,
                onResend: ctx.resend
            )

        case .additionalStep:
            if let view = ctx.additionalStepView { view } else { LoginLoadingScreen() }

        case .additionalStepUnavailable:
            LoginAdditionalStepUnavailableScreen { ctx.dispatch(.restart) }

        case .authenticated:
            LoginSuccessScreen()

        case let .failed(message):
            LoginErrorScreen(message: message) { ctx.dispatch(.retry) }

        case .noMethods:
            LoginNoMethodsScreen(onBack: ctx.back)
        }
    }

    /// The first of several ways gets the shared screen with "OR"; a way on its own gets its own screen.
    @ViewBuilder
    private func identifierScreen(_ channel: LoginChannel, alternatives: [LoginChannel],
                                  context ctx: RenderContext) -> some View {
        let prefill = ctx.identifier?.channel == channel ? ctx.identifier : nil
        let error = ctx.inputError?.message(for: channel)
        if !alternatives.isEmpty {
            LoginIdentifierScreen(channel: channel, alternatives: alternatives, prefill: prefill,
                                  isLoading: ctx.isSubmitting, errorMessage: error,
                                  onContinue: { ctx.dispatch(.submitIdentifier($0)) },
                                  onChoose: { ctx.dispatch(.chooseChannel($0)) })
        } else {
            switch channel {
            case .email:
                LoginEmailScreen(email: prefill?.value ?? "", isLoading: ctx.isSubmitting, errorMessage: error) {
                    ctx.dispatch(.submitIdentifier(.email($0)))
                }
            case .phone:
                LoginPhoneScreen(number: prefill?.value ?? "", isLoading: ctx.isSubmitting, errorMessage: error) {
                    ctx.dispatch(.submitIdentifier(.phone($0)))
                }
            }
        }
    }
}
