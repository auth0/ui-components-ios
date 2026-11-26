import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What a toast waits on. The live one sleeps; a test hands over a clock it moves itself.
@MainActor
protocol ToastSleeping {
    /// Returns after `seconds`, or throws `CancellationError` when the task is cancelled first.
    func sleep(seconds: TimeInterval) async throws
}

struct LiveToastSleeper: ToastSleeping {
    func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: ToastBehavior.nanoseconds(seconds))
    }
}

/// Has VoiceOver read a toast, without moving focus to it.
enum ToastAnnouncer {
    @MainActor
    static func announce(_ text: String) {
        if #available(iOS 17, macOS 14, visionOS 1, *) {
            // High priority, so it isn't left behind other speech. Worth checking on a device.
            var spoken = AttributedString(text)
            spoken.accessibilitySpeechAnnouncementPriority = .high
            AccessibilityNotification.Announcement(spoken).post()
        } else {
            // iOS 16 and macOS 13, which have no priority to give.
            #if canImport(UIKit)
            UIAccessibility.post(notification: .announcement, argument: text)
            #elseif canImport(AppKit)
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                                 userInfo: [.announcement: text,
                                            .priority: NSAccessibilityPriorityLevel.high.rawValue])
            #endif
        }
    }
}

/// Runs one toast at a time: when it is announced, how long it rests, and when it goes. It holds the state the
/// modifier can't test, and the modifier only draws and forwards what happens on screen.
///
/// Every call that names a toast carries its `id`, and is ignored when that toast is no longer the current one, so
/// a late timer, drag or measurement can't touch the toast that replaced it.
@MainActor
final class ToastPresenter {

    /// Clears the app's binding if `id` is still what it holds. Set by the modifier, on every update.
    var clear: ((UUID) -> Void)?

    private(set) var current: Auth0ToastMessage?

    private let sleeper: ToastSleeping
    private let announce: (String) -> Void

    /// Set while the host isn't on screen, and shown when it is.
    private var pending: Auth0ToastMessage?
    private var isHostVisible = false
    private var isDragging = false
    private var announced = false
    /// What the layout reported, and for which toast. The layout can report before the presenter has started the toast,
    /// so it is kept by id and read only for that toast, never reset.
    private var measurement: (id: UUID, wraps: Bool)?
    private var voiceOverRunning = false
    private var announceTask: Task<Void, Never>?
    private var restTask: Task<Void, Never>?

    /// Without arguments it sleeps for real and announces to VoiceOver; a test passes its own.
    init(sleeper: ToastSleeping? = nil, announce: ((String) -> Void)? = nil) {
        self.sleeper = sleeper ?? LiveToastSleeper()
        self.announce = announce ?? { ToastAnnouncer.announce($0) }
    }

    // MARK: The app

    /// What the app's binding holds now. A new message replaces the current one.
    func sync(_ message: Auth0ToastMessage?) {
        guard let message else {
            stop()
            current = nil
            pending = nil
            return
        }
        guard message.id != current?.id, message.id != pending?.id else { return }
        if isHostVisible {
            start(message)
        } else {
            stop()
            current = nil
            pending = message
        }
    }

    // MARK: The host

    func hostAppeared() {
        isHostVisible = true
        if let waiting = pending {
            pending = nil
            start(waiting)
        }
    }

    /// The screen is gone, so the toast goes with it. Without this it would show again, and be announced again, when
    /// the screen came back.
    func hostDisappeared() {
        isHostVisible = false
        let id = (current ?? pending)?.id
        stop()
        current = nil
        pending = nil
        if let id { clear?(id) }
    }

    // MARK: The toast

    func dismiss(id: UUID) {
        finish(id)
    }

    /// The message was laid out: whether it needs a second line. Used when the hold is decided, for this toast only.
    func measured(wraps: Bool, id: UUID) {
        measurement = (id, wraps)
    }

    func voiceOverChanged(_ isRunning: Bool) {
        voiceOverRunning = isRunning
    }

    /// A drag started or stopped (it also stops when the system cancels it). The toast doesn't leave under a finger.
    func dragChanged(active: Bool, id: UUID) {
        guard current?.id == id else { return }
        if active {
            isDragging = true
            restTask?.cancel()
            restTask = nil
        } else if isDragging {
            isDragging = false
            startRest()
        }
    }

    /// A drag ended past the distance, away from the toast's edge: the toast goes. Short of it, `dragChanged`
    /// restarts the hold.
    func dragEnded(id: UUID, translation: CGFloat, edge: VerticalEdge = .top) {
        guard current?.id == id, ToastBehavior.shouldDismiss(swipe: translation, edge: edge) else { return }
        finish(id)
    }

    // MARK: Timing

    private func start(_ message: Auth0ToastMessage) {
        stop()
        current = message
        announced = false
        isDragging = false
        announceTask = Task { [weak self] in await self?.appear(message) }
    }

    /// After the fade-in, and so after the toast was laid out: announce it, then let it rest.
    private func appear(_ message: Auth0ToastMessage) async {
        do { try await sleeper.sleep(seconds: ToastBehavior.appearDuration) } catch { return }
        guard !Task.isCancelled, current?.id == message.id else { return }
        announced = true
        announce(message.text)
        startRest()
    }

    private func startRest() {
        guard let message = current, announced, !isDragging else { return }
        restTask?.cancel()
        restTask = Task { [weak self] in await self?.rest(message) }
    }

    private func rest(_ message: Auth0ToastMessage) async {
        let wraps = measurement?.id == message.id && measurement?.wraps == true
        let hold = ToastBehavior.hold(wraps: wraps, voiceOverRunning: voiceOverRunning, duration: message.duration)
        do { try await sleeper.sleep(seconds: hold) } catch { return }
        // A sleep that ended just as the task was cancelled doesn't throw: check, so a stale timer can't clear a toast.
        guard !Task.isCancelled, current?.id == message.id, !isDragging else { return }
        finish(message.id)
    }

    private func finish(_ id: UUID) {
        guard current?.id == id else { return }
        stop()
        current = nil
        clear?(id)
    }

    private func stop() {
        announceTask?.cancel()
        restTask?.cancel()
        announceTask = nil
        restTask = nil
    }
}
