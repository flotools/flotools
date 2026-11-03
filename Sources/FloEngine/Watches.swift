import FloSystem

/// Watches started by commands that keep running after the command returns, such as the level meter monitor. They run outside the command queue, so other commands keep working while one watches. Each is keyed by the command that starts and stops it, so one command has at most one watch.
///
/// Owned by the main actor. A watch ends when its command toggles it off, when its body returns, or with `stopAll()`, which the engine calls when it cancels all commands or stops. Ending a watch cancels its task, so the body hears about it as `CancellationError` and can say goodbye.
@MainActor
public final class Watches {
    public typealias Body = @Sendable () async -> Void

    /// The running watch of each command, by its number.
    private var active: [CommandID: Int] = [:]
    /// Every watch task whose body has not returned yet, by number, including stopped ones that are still saying goodbye, so `stopAll()` can wait for them too.
    private var unfinished: [Int: Task<Void, Never>] = [:]
    private var count = 0

    public init() {}

    public func isRunning(_ id: CommandID) -> Bool { active[id] != nil }

    /// Stops the watch of `id` if it runs, otherwise starts `body` as that watch. Returns whether a watch runs now.
    @discardableResult
    public func toggle(_ id: CommandID, _ body: @escaping Body) -> Bool {
        if isRunning(id) {
            stop(id)
            return false
        }
        Log.info(.engine, "\(id) watch started")
        count += 1
        let number = count
        // The task inherits the starting run's invocation ID, so its log lines can be followed.
        // Starts only after this method returns, on the main actor, so it is registered before it can finish.
        let task = Task { @MainActor [weak self] in
            await body()
            self?.finished(id, number)
        }
        active[id] = number
        unfinished[number] = task
        return true
    }

    /// Stops the watch of `id`, if it runs. Its task stays in `unfinished` until its body returns.
    public func stop(_ id: CommandID) {
        guard let number = active.removeValue(forKey: id) else { return }
        Log.info(.engine, "\(id) watch stopped")
        unfinished[number]?.cancel()
    }

    /// Stops every watch. The returned task ends once all their bodies have returned, also those of watches stopped earlier that are still ending.
    @discardableResult
    public func stopAll() -> Task<Void, Never> {
        let stopped = Array(unfinished.values)
        active = [:]
        if !stopped.isEmpty { Log.info(.engine, "stopping \(stopped.count) watch(es)") }
        stopped.forEach { $0.cancel() }
        return Task { @MainActor in
            for task in stopped { await task.value }
        }
    }

    /// A watch that ended by itself is no longer running; one stopped and replaced meanwhile is not the running one.
    private func finished(_ id: CommandID, _ number: Int) {
        unfinished[number] = nil
        if active[id] == number { active[id] = nil }
    }
}

extension Watches {
    /// How often a watch reads Pro Tools, as the JXA monitors waited 0.1 s between reads. Its gain reduction monitor did not wait at all.
    public nonisolated static let pollInterval: Duration = .milliseconds(100)

    /// Waits `pollInterval` before a watch's next read. False when the watch was cancelled before or during the wait, so the loop ends without another read.
    public nonisolated static func waitForNextPoll() async -> Bool {
        guard !Task.isCancelled else { return false }
        try? await Task.sleep(for: pollInterval)
        return !Task.isCancelled
    }
}

/// A run of failed reads by a loop that polls Pro Tools ten times a second, such as a watch or the freeze wait, so it logs only the first failure of a run and the first good read after it. What a failure does to the loop, such as dropping a watch's baseline or ending it, stays with the loop.
public struct ReadFailureStreak: Sendable {
    /// What the loop reads, for the log, for example "the meter".
    public let what: String
    public private(set) var isFailing = false

    public init(reading what: String) {
        self.what = what
    }

    public mutating func failed(_ error: any Error) {
        if !isFailing { Log.info(.engine, "could not read \(what): \(error)") }
        isFailing = true
    }

    public mutating func succeeded() {
        if isFailing { Log.info(.engine, "reads \(what) again") }
        isFailing = false
    }
}
