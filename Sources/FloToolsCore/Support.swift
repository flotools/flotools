import AppKit
import Foundation

/// Tells a single press from a double press of the same command.
///
/// The Keyboard Maestro version stored "command.timestamp" in a shared variable and polled it. Here a single press waits for the timeout and is cancelled if the same command is pressed again in time, which then runs the double action right away.
@MainActor
public final class DoublePress {
    public static let shared = DoublePress()

    public var timeout: Duration

    private var pending: [String: (time: ContinuousClock.Instant, task: Task<Void, Never>)] = [:]

    public init(timeout: Duration = .milliseconds(200)) {
        self.timeout = timeout
    }

    public func press(_ command: String, single: @escaping @MainActor () -> Void, double: @escaping @MainActor () -> Void) {
        let now = ContinuousClock.now
        if let previous = pending.removeValue(forKey: command), now - previous.time < timeout {
            previous.task.cancel()
            double()
            return
        }
        let wait = timeout
        let task = Task { @MainActor in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled else { return }
            self.pending[command] = nil
            single()
        }
        pending[command] = (now, task)
    }
}

/// System sounds used as feedback, like `kme.playSound(Path("/System/Library/Sounds/Tink.aiff"))`.
@MainActor
public enum Sound {
    public static func play(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}

/// The preferences file shared with the Keyboard Maestro version: `~/Library/Application Support/Flo Tools/flotools.json`.
public struct Preferences: Equatable, Sendable {
    public var temporaryInspector = false
    public var startsWithInspector = false
    /// Double-press timeout in milliseconds.
    public var timeout = 200

    public init() {}

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Flo Tools/flotools.json")
    }

    public static func load(from url: URL = defaultURL) -> Preferences {
        guard let data = try? Data(contentsOf: url) else { return Preferences() }
        return decode(data)
    }

    static func decode(_ data: Data) -> Preferences {
        var prefs = Preferences()
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return prefs }
        prefs.temporaryInspector = json["temporary inspector"] as? Bool ?? false
        prefs.startsWithInspector = json["starts with Flo Tools inspector"] as? Bool ?? false
        if let text = json["timeout"] as? String, let ms = Int(text) {
            prefs.timeout = ms
        } else if let ms = json["timeout"] as? Int {
            prefs.timeout = ms
        }
        return prefs
    }

    /// Writes the same JSON shape as the Keyboard Maestro version, with the timeout as a string.
    public func save(to url: URL = defaultURL) throws {
        let json: [String: Any] = [
            "temporary inspector": temporaryInspector,
            "starts with Flo Tools inspector": startsWithInspector,
            "timeout": String(timeout),
        ]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]).write(to: url)
    }
}
