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
