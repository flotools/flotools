import FloSystem

/// Waiting for Pro Tools to show the result of a key or click. Measured 2026-11-02: fade dialog settings changed 27 to 58 ms after the key, track buttons 10 to 73 ms after AXPress.
public enum ProToolsUpdate {
    public static let timeout: Duration = .milliseconds(200)

    /// Reads until the reading differs from `before` or `limit` passes, and returns the last reading. Some actions change nothing, such as a key at the end of a list or arming a track without an input, so an unchanged reading is not an error.
    @AccessibilityActor
    public static func reading<Value: Equatable>(changedFrom before: Value, within limit: Duration = timeout, _ read: @AccessibilityActor () throws -> Value) async throws -> Value {
        let start = ContinuousClock.now
        var now = try read()
        while now == before, ContinuousClock.now - start < limit {
            try await Task.sleep(for: .milliseconds(10))
            now = try read()
        }
        return now
    }

    /// Reads, runs `action` (a press or click), then reads until the reading differs from the first one, as `reading(changedFrom:)`. The one `read` gives both readings, so they cannot drift apart.
    @AccessibilityActor
    public static func reading<Value: Equatable>(after action: @AccessibilityActor () throws -> Void, within limit: Duration = timeout, _ read: @AccessibilityActor () throws -> Value) async throws -> Value {
        let before = try read()
        try action()
        return try await reading(changedFrom: before, within: limit, read)
    }
}
