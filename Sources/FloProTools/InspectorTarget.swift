import FloSystem
import Foundation

/// The track the VoiceOver cursor was on when Auto Inspector accepted a press: its name, the group the cursor was on and the window that group is in. The engine also pins the front window the press came from.
public struct InspectorTarget: Sendable {
    public let processID: pid_t
    public let name: String
    /// The track's group in `window`. Compared by AX identity, so a strip removed and recreated with the same name is another track.
    private let source: AXElement
    private let window: ProToolsApp.TrackWindow

    init(processID: pid_t, name: String, source: AXElement, window: ProToolsApp.TrackWindow) {
        self.processID = processID
        self.name = name
        self.source = source
        self.window = window
    }

    @AccessibilityActor
    public func isSameTrack(as other: Self) -> Bool {
        processID == other.processID && name == other.name && source.isSame(as: other.source)
    }

    /// The accepted track as shown in `requestedWindow`. Throws when the accepted group is gone or renamed, or, for the other window, when the name does not point at one track there, rather than run on another track.
    ///
    /// The accepted group itself is checked rather than found again by name: its AX identity already pins the track, and a scan costs a read per strip (about 20 ms with 220 tracks, measured 2026-11-08).
    @AccessibilityActor
    public func track(in requestedWindow: ProToolsApp.TrackWindow) throws -> TrackStrip {
        try checkSourceStillNamed()
        if window == requestedWindow { return TrackStrip(name: name, element: source) }
        let app = ProToolsApp(pid: processID)
        return TrackStrip(name: name, element: try ProToolsApp.uniqueGroup(named: name, in: app.trackWindow(requestedWindow)).required("the unique track \(name)"))
    }

    /// A strip that was removed, even if recreated with the same name, is another element, whose reads fail as invalid.
    @AccessibilityActor
    private func checkSourceStillNamed() throws {
        let current: String?
        do {
            current = try source.name
        } catch {
            Log.debug(.accessibility, "could not read the accepted Inspector track: \(error)")
            current = nil
        }
        guard current == name else { throw FloError.couldNot("find the accepted Inspector track") }
    }
}

extension ProToolsApp {
    /// The track whose name the VoiceOver cursor is on in `window`, or nil when the cursor is on anything else. Only a track's own group counts, matched by exactly the cursor's text and frame, so a control inside the strip is not taken for the track. Throws when `window` is not in front.
    public func inspectorTargetUnderVoiceOverCursor(in window: TrackWindow) async throws -> InspectorTarget? {
        let cursor = try await VoiceOver.cursorSnapshot()
        return try await inspectorTarget(text: cursor.text, bounds: cursor.bounds, in: window)
    }

    @AccessibilityActor
    private func inspectorTarget(text: String?, bounds: CGRect, in window: TrackWindow) throws -> InspectorTarget? {
        let focused = try frontWindow()
        guard try focused.name.map(ProToolsWindowKind.init(title:)) == window.kind else {
            throw FloError.couldNot("identify the front Inspector window")
        }
        guard let text, !text.isEmpty else { return nil }
        guard let group = try Self.uniqueGroup(named: text, in: focused), let frame = try group.frame,
            Self.isInspectorName(text: text, bounds: bounds, name: text, frame: frame) else { return nil }
        return InspectorTarget(processID: pid, name: text, source: group, window: window)
    }

    /// The only group named `name` among the window's immediate children, or nil when there is none or more than one. Auto Inspector needs the name to point at one track.
    ///
    /// Names are read first and roles only for matches, so a window of N children costs about N reads rather than 2N.
    @AccessibilityActor
    static func uniqueGroup(named name: String, in window: AXElement) throws -> AXElement? {
        let matches = try window.children.filter { try $0.name == name && $0.role == "AXGroup" }
        return matches.count == 1 ? matches.first : nil
    }

    /// Whether the cursor (`text`, `bounds`) is exactly on a track name group (`name`, `frame`). Equality rather than containment, so a partial name or a control inside the strip does not count, nor does a frame that is empty or not finite.
    nonisolated static func isInspectorName(text: String?, bounds: CGRect, name: String, frame: CGRect) -> Bool {
        name.range(of: #" - (?:\w+ )+track\s*$"#, options: [.regularExpression, .caseInsensitive]) != nil
            && text == name && validNameFrame(bounds) && validNameFrame(frame) && bounds == frame
    }

    private nonisolated static func validNameFrame(_ frame: CGRect) -> Bool {
        [frame.origin.x, frame.origin.y, frame.size.width, frame.size.height].allSatisfy(\.isFinite)
            && frame.width > 0 && frame.height > 0 && !frame.isNull && !frame.isInfinite
    }
}
