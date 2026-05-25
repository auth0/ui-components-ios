@testable import Auth0UniversalComponents
import Foundation

final class MockTelemetryEventProvider: TelemetryEventProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [TelemetryEvent] = []

    var events: [TelemetryEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _events
    }

    func track(event: TelemetryEvent) {
        lock.lock()
        defer { lock.unlock() }
        _events.append(event)
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _events.removeAll()
    }

    func events(named name: String) -> [TelemetryEvent] {
        events.filter { $0.name == name }
    }

    func events(ofCategory category: TelemetryEvent.EventCategory) -> [TelemetryEvent] {
        events.filter { $0.category == category }
    }
}
