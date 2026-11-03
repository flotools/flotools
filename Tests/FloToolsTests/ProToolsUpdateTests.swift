import Testing
import FloSystem
@testable import FloProTools

@Suite struct ProToolsUpdateTests {
    /// The first reading comes before the action, so a value the action changes is returned without waiting out the limit.
    @Test @AccessibilityActor func readingAfterActionReturnsTheChange() async throws {
        var state = "off"
        var reads: [String] = []
        let start = ContinuousClock.now
        let result = try await ProToolsUpdate.reading(after: { state = "on" }, within: .seconds(5)) {
            reads.append(state)
            return state
        }
        #expect(result == "on")
        #expect(reads == ["off", "on"])
        #expect(ContinuousClock.now - start < .seconds(1))
    }

    /// An action that changes nothing, such as arming a track without an input, returns the unchanged reading after the limit.
    @Test @AccessibilityActor func readingAfterActionThatChangesNothing() async throws {
        let result = try await ProToolsUpdate.reading(after: {}, within: .milliseconds(30)) { "off" }
        #expect(result == "off")
    }
}
