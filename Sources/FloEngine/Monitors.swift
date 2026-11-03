import FloSystem

/// Watches started by macros that keep running after the macro returns, such as the level meter monitor. They run outside the macro queue, so other macros keep working while one watches. Each is keyed by the macro that starts and stops it, so one macro has at most one watch.
///
/// Owned by the main actor. A watch ends when its macro toggles it off, when its body returns, or with `stopAll()`, which the engine calls when it stops. Ending a watch cancels its task, so the body hears about it as `CancellationError` and can say goodbye.
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
        if let watch = tasks.removeValue(forKey: id) {
            Log.info(.engine, "\(id) watch stopped")
            watch.task.cancel()
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

    public func stopAll() {
        guard !tasks.isEmpty else { return }
        Log.info(.engine, "stopping \(tasks.count) watch(es)")
        tasks.values.forEach { $0.task.cancel() }
        tasks = [:]
    }
}
