import FloSystem
import Foundation

/// A track name accepted for one process. The routing context separately pins its front window.
public struct InspectorTarget: Sendable {
    public let processID: pid_t
    public let name: String

    private let source: AXElement?
    private let window: ProToolsApp.TrackWindow?

    init(processID: pid_t, name: String) {
        self.processID = processID
        self.name = name
        source = nil
        window = nil
    }

    fileprivate init(processID: pid_t, name: String, source: AXElement, window: ProToolsApp.TrackWindow) {
        self.processID = processID
        self.name = name
        self.source = source
        self.window = window
    }

    /// AX identity distinguishes a removed and recreated strip with the same name.
    @AccessibilityActor
    public func isSameTrack(as other: Self) -> Bool {
        guard processID == other.processID, name == other.name else { return false }
        switch (source, other.source) {
        case (.some(let first), .some(let second)): return first.isSame(as: second)
        case (nil, nil): return true
        default: return false
        }
    }

    /// Validate the accepted source identity before mapping its exact name into the command's window. Missing or duplicate names fail rather than choose another track.
    @AccessibilityActor
    public func track(in requestedWindow: ProToolsApp.TrackWindow) throws -> TrackStrip {
        let app = ProToolsApp(pid: processID)
        if let source, let window {
            let current = try Self.uniqueGroup(name: name, in: app.trackWindow(window))
            guard current.isSame(as: source) else { throw FloError.couldNot("find the accepted Inspector track") }
            if window == requestedWindow { return TrackStrip(name: name, element: source) }
        }
        return TrackStrip(name: name, element: try Self.uniqueGroup(name: name, in: app.trackWindow(requestedWindow)))
    }

    @AccessibilityActor
    private static func uniqueGroup(name: String, in window: AXElement) throws -> AXElement {
        let matches = try window.groups.filter { try $0.name == name }
        guard matches.count == 1, let group = matches.first else { throw FloError.notFound("the unique track \(name)") }
        return group
    }
}

extension ProToolsApp {
    /// Conservative baseline: only the named immediate track group with exactly the cursor's text and frame. A child control inside the strip is not a track-name cursor. Name pop-ups await live validation.
    public func inspectorTargetUnderVoiceOverCursor(in window: TrackWindow) async throws -> InspectorTarget? {
        let cursor = try await VoiceOver.cursorSnapshot()
        return try await inspectorTarget(text: cursor.text, bounds: cursor.bounds, in: window)
    }

    @AccessibilityActor
    private func inspectorTarget(text: String?, bounds: CGRect, in window: TrackWindow) throws -> InspectorTarget? {
        let focused = try frontWindow()
        guard try focused.title.map(ProToolsWindowKind.init(title:)) == window.kind else {
            throw FloError.couldNot("identify the front Inspector window")
        }
        guard let text, !text.isEmpty else { return nil }
        let groups = try focused.groups.filter { try $0.name == text }
        guard groups.count == 1, let group = groups.first, let frame = try group.frame,
            Self.isInspectorName(text: text, bounds: bounds, name: text, frame: frame) else { return nil }
        return InspectorTarget(processID: pid, name: text, source: group, window: window)
    }

    /// Exact equality deliberately rejects containment, partial names and invalid geometry.
    nonisolated static func isInspectorName(text: String?, bounds: CGRect, name: String, frame: CGRect) -> Bool {
        name.range(of: #" - (?:\w+ )+track\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil
            && text == name && validNameFrame(bounds) && validNameFrame(frame) && bounds == frame
    }

    private nonisolated static func validNameFrame(_ frame: CGRect) -> Bool {
        [frame.origin.x, frame.origin.y, frame.size.width, frame.size.height].allSatisfy(\.isFinite)
            && frame.width > 0 && frame.height > 0 && !frame.isNull && !frame.isInfinite
    }
}
