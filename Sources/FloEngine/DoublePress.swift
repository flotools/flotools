import Foundation

/// Tells a single press from a double press of the same command.
///
/// The Keyboard Maestro version stored "command.timestamp" in a shared variable and polled it. Here a single press waits for the timeout and is cancelled if the same command is pressed again in time, which then runs the double action right away.
@MainActor
public final class DoublePress {
    public static let shared = DoublePress()

    public var timeout: Duration

    private var pending: [String: (time: ContinuousClock.Instant, task: Task<Void, Never>)] = [:]

    public init(timeout: Duration = .milliseconds(200)) {
        self.timeout = timeout
    }

    public func press(_ command: String, single: @escaping @MainActor () -> Void, double: @escaping @MainActor () -> Void) {
        let now = ContinuousClock.now
        if let previous = pending.removeValue(forKey: command), now - previous.time < timeout {
            previous.task.cancel()
            double()
            return
        }
        let wait = timeout
        let task = Task { @MainActor in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self.pending[command] = nil
            single()
        }
        pending[command] = (now, task)
    }
}
