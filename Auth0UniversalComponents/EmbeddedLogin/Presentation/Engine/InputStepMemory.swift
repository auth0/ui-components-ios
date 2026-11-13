/// The input screen the user was last on. While a request is in flight the coordinator is `.loading`; showing this
/// screen then, with progress in its button, keeps its shape (including the alternative it offers) instead of redrawing
/// it as a spinner.
struct InputStepMemory: Equatable {
    private(set) var last: LoginStep?

    mutating func track(_ step: LoginStep) {
        switch step {
        case .collectOTPIdentifier, .collectOTPCode, .collectPassword:
            last = step
        case .loading:
            break
        default:
            last = nil
        }
    }

    /// What to show for `step`: the last input screen while loading, else `step` itself.
    func displayed(for step: LoginStep) -> LoginStep {
        if case .loading = step, let last { return last }
        return step
    }
}
