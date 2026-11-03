import FloSystem

/// Watches started by macros that keep running after the macro returns, such as the level meter monitor. They run outside the macro queue, so other macros keep working while one watches. Each is keyed by the macro that starts and stops it, so one macro has at most one watch.
///
/// Owned by the main actor. A watch ends when its macro toggles it off, when its body returns, or with `stopAll()`, which the engine calls when it cancels all macros or stops. Ending a watch cancels its task, so the body hears about it as `CancellationError` and can say goodbye.
@MainActor
public final class Monitors {
    public typealias Body = @Sendable () async -> Void

    private var tasks: [MacroID: (number: Int, task: Task<Void, Never>)] = [:]
    private var count = 0

    public init() {}

    public func isRunning(_ id: MacroID) -> Bool { tasks[id] != nil }

    /// Stops the watch of `id` if it runs, otherwise starts `body` as that watch. Returns whether a watch runs now.
    @discardableResult
    public func toggle(_ id: MacroID, _ body: @escaping Body) -> Bool {
        if isRunning(id) {
            stop(id)
            return false
        }
        Log.info(.engine, "\(id) watch started")
        count += 1
        let number = count
        // The task inherits the starting run's invocation ID, so its log lines can be followed.
        let task = Task { @MainActor [weak self] in
            await body()
            // A watch that ended by itself is forgotten; one stopped and replaced meanwhile is not this one.
            if self?.tasks[id]?.number == number { self?.tasks[id] = nil }
        }
        tasks[id] = (number, task)
        return true
    }

    /// Stops the watch of `id`, if it runs.
    public func stop(_ id: MacroID) {
        guard let watch = tasks.removeValue(forKey: id) else { return }
        Log.info(.engine, "\(id) watch stopped")
        watch.task.cancel()
    }

    /// Stops every watch. The returned task ends once their bodies have returned.
    @discardableResult
    public func stopAll() -> Task<Void, Never> {
        let stopped = tasks.values.map(\.task)
        tasks = [:]
        if !stopped.isEmpty { Log.info(.engine, "stopping \(stopped.count) watch(es)") }
        stopped.forEach { $0.cancel() }
        return Task { @MainActor in
            for task in stopped { await task.value }
        }
    }
}

extension Monitors {
    /// How often a watch reads Pro Tools, as the JXA monitors waited 0.1 s between reads. Its gain reduction monitor did not wait at all.
    public nonisolated static let pollInterval: Duration = .milliseconds(100)
}

/// A watch's run of failed reads. A watch polls ten times a second, so it logs only the first failure of a run and the first good read after it. What a failure does to the watch, such as dropping its baseline or ending it, stays with the watch.
public struct ReadFailureStreak: Sendable {
    /// What the watch reads, for the log, for example "the meter".
    public let what: String
    public private(set) var isFailing = false

    public init(reading what: String) {
        self.what = what
    }

    public mutating func failed(_ error: any Error) {
        if !isFailing { Log.info(.engine, "watch could not read \(what): \(error)") }
        isFailing = true
    }

    public mutating func succeeded() {
        if isFailing { Log.info(.engine, "watch reads \(what) again") }
        isFailing = false
    }
}
