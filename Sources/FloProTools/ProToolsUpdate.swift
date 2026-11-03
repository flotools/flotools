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
}
