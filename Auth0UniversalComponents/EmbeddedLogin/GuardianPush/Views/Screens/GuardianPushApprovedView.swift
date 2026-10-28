import SwiftUI

/// Shown briefly once Guardian approves.
public struct GuardianPushApprovedView: View {
    public init() {}

    public var body: some View {
        GuardianPushStatusLayout(title: "Approved.", message: "Finishing sign-in…") { EmptyView() }
    }
}
