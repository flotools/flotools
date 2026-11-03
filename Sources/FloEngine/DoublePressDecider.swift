/// Tells a single press of a command's key from a double press, given the time of each press. Pure, so it is tested with explicit instants; the engine owns the timer and the runs.
///
/// The Keyboard Maestro version stored "command.timestamp" in a shared variable and polled it. Here the first press becomes a pending single with a generation number. A second press within the timeout turns it into a double; otherwise the engine's timer finds the single still due and runs it.
public struct DoublePressDecider: Sendable {
    public enum Decision: Equatable, Sendable {
        /// Run the double action now; the pending single is void.
        case double
        /// Wait for the timeout, then run the single action if `singleIsDue` still says so.
        case single(generation: Int)
    }

    public var timeout: Duration
    private var pending: [CommandID: (time: ContinuousClock.Instant, generation: Int)] = [:]
    private var lastGeneration = 0

    public init(timeout: Duration) {
        self.timeout = timeout
    }

    public mutating func press(_ id: CommandID, at now: ContinuousClock.Instant) -> Decision {
        if let previous = pending.removeValue(forKey: id), now - previous.time < timeout {
            return .double
        }
        lastGeneration += 1
        pending[id] = (now, lastGeneration)
        return .single(generation: lastGeneration)
    }

    /// Called when the wait for a single press ends. True at most once per single, and false if a second press or `cancelAll` came first.
    public mutating func singleIsDue(_ id: CommandID, generation: Int) -> Bool {
        guard pending[id]?.generation == generation else { return false }
        pending[id] = nil
        return true
    }

    /// Voids every pending single.
    public mutating func cancelAll() {
        pending = [:]
    }
}
