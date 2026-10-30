import Auth0
import SwiftUI

// The login's contract for "the server wants more than the email code". The login owns these types and knows nothing
// about what plugs into them: it starts an additional step, shows its view, and hears how it ended. Whatever runs
// the additional step (whatever is plugged in) implements `AdditionalStepProviding`.
//
// A provider is asked for a new session every time the login needs one (each new sign-in, after Back or "Start
// over"), so it must keep nothing between sessions. Whatever runs in a session handles its own repeats: MFA, for one,
// runs every factor a policy needs inside a single session.

/// What the first factor leaves for an additional step to continue: the server's menu, and the same sign-in session.
struct AdditionalStepContext {
    let nextActions: [NextAction]
    let client: EmbeddedAuthClient
    let credentialsStore: CredentialsStoring
}

extension AdditionalStepContext: Equatable {
    static func == (lhs: AdditionalStepContext, rhs: AdditionalStepContext) -> Bool {
        lhs.nextActions == rhs.nextActions
    }
}

/// How an additional step ended.
enum AdditionalStepResult: Equatable {
    /// The user is signed in and the credentials are stored.
    case completed
    /// The user backed out. The login starts again at the first screen.
    case cancelled
    /// Nothing this flow can run. `reported` is true when the app was told and will route the user itself.
    case unavailable(reported: Bool)
    /// It failed in a way it shows itself, with its own way out.
    case failed
}

@MainActor
protocol AdditionalStepDelegate: AnyObject {
    func additionalStepDidFinish(_ result: AdditionalStepResult)
    /// The user chose to begin again from the additional step's own screen.
    func additionalStepRequestedRestart()
}

/// One running additional step.
@MainActor
protocol AdditionalStepSession: AnyObject {
    /// What the login shows while the additional step runs.
    var view: AnyView { get }
    var isFinished: Bool { get }
    func start()
    /// Ends it. Also called once it has finished, when the login leaves its last screen: it must show nothing more.
    func cancel()
    /// Ends it and waits for the request in flight: the SDK allows one at a time.
    func cancelAndWait() async
}

@MainActor
protocol AdditionalStepProviding {
    func makeSession(context: AdditionalStepContext, delegate: AdditionalStepDelegate) -> AdditionalStepSession
}
