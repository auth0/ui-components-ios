import SwiftUI

// Maps a `LoginStep` to a `ScreenPlan` and builds its screen. Input goes back via `RenderContext`.

/// What a screen needs from the host, without knowing about the coordinator.
struct RenderContext {
    var isSubmitting: Bool
    var inputError: AuthFailure?
    let dispatch: (LoginEvent) -> Void
    let resend: () -> Void
    let back: () -> Void
}

enum ScreenPlan: Equatable {
    case loading
    case identifier
    case otpCode(identifier: String)
    case mfaCode(factor: MFAFactor, destination: String?)
    case authenticated
    case failed(message: String)
    case noMethods
}

extension ScreenPlan {
    /// Identifies the *screen*, ignoring inline payload, so payload changes don't transition.
    var transitionIdentity: String {
        switch self {
        case .loading:                return "loading"
        case .identifier:             return "identifier"
        case .otpCode:                return "otpCode"
        case let .mfaCode(factor, _): return "mfaCode.\(factor)"
        case .authenticated:          return "authenticated"
        case .failed:                 return "failed"
        case .noMethods:              return "noMethods"
        }
    }

    /// Compared across a change to pick a push (deeper) or pop (shallower).
    var navigationDepth: Int {
        switch self {
        case .loading:                return 0
        case .identifier, .noMethods: return 1
        case .otpCode, .mfaCode:      return 2
        case .authenticated, .failed: return 3
        }
    }
}

struct LoginRenderer {

    func plan(for step: LoginStep) -> ScreenPlan {
        switch step {
        case .loading:                    return .loading
        case .collectOTPIdentifier:       return .identifier
        case let .collectOTPCode(email):  return .otpCode(identifier: email)
        case let .stepUpMFA(challenge):   return .mfaCode(factor: challenge.factor, destination: challenge.destination)
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

        case .identifier:
            LoginEmailScreen(isLoading: ctx.isSubmitting, errorMessage: ctx.inputError?.message) {
                ctx.dispatch(.submitIdentifier($0))
            }

        case let .otpCode(identifier):
            LoginCodeScreen(
                subtitle: "From \(identifier)",
                isLoading: ctx.isSubmitting,
                errorMessage: ctx.inputError?.message,
                onVerify: { ctx.dispatch(.submitOTP(code: $0)) },
                onEdit: ctx.back,
                onResend: ctx.resend
            )

        case let .mfaCode(factor, destination):
            LoginCodeScreen(
                subtitle: factor.codeSourceHint(destination: destination),
                isLoading: ctx.isSubmitting,
                errorMessage: ctx.inputError?.message,
                onVerify: { ctx.dispatch(.submitMFA(code: $0)) }
            )

        case .authenticated:
            LoginSuccessScreen()

        case let .failed(message):
            LoginErrorScreen(message: message) { ctx.dispatch(.retry) }

        case .noMethods:
            LoginNoMethodsScreen(onBack: ctx.back)
        }
    }
}
