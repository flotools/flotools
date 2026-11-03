import FloSystem
import Foundation

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
        guard let data = try? Data(contentsOf: url) else {
            Log.info(.preferences, "no preferences file, using defaults")
            return Preferences()
        }
        let preferences = decode(data)
        Log.info(.preferences, "loaded \(preferences)")
        return preferences
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
