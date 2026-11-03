import CoreGraphics
import FloSystem
import Foundation

/// A Flo Tools plug-in view: a file the user writes that lays a plug-in's parameters out in rows and columns, with where each control is in the plug-in window, so the parameter commands can walk them with Ctrl+arrows and move the mouse to each. The format and folder are the KM version's, so existing files keep working.
///
/// The file is JSON in a `.txt` file in `~/Library/Application Support/Flo Tools/Plug-In Views/`, named after the plug-in, with "-N" for view N:
///
///     {"view":"Default", "click":[-1,-1], "parameters":[
///     [["Knee Width",200,290], ["Ratio",200,356]],
///     [["Gain",450,290]]
///     ]}
///
/// Positions are relative to the window's top-left corner. `click` is a point clicked when the view loads, for example to pick a tab of the plug-in; -1 means none.
struct PlugInView: Sendable, Equatable {
    struct Parameter: Sendable, Equatable {
        let name: String
        /// Where the control is, relative to the window. `.zero` is the template's placeholder for "not placed yet".
        let point: CGPoint
    }

    /// The view's name as spoken, for example "Default" or "View 1".
    let name: String
    let click: CGPoint?
    let rows: [[Parameter]]

    /// Throws `FloError.unexpectedValue` naming what is wrong, so the author of a file can fix it.
    init(json: Data) throws {
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { throw FloError.unexpectedValue("the view file is not a JSON object") }
        guard let name = object["view"] as? String else { throw FloError.unexpectedValue("the view file has no \"view\" name") }
        guard let click = Self.point(object["click"]) else { throw FloError.unexpectedValue("the view file's \"click\" is not two numbers of a window position") }
        guard let rows = object["parameters"] as? [[Any]] else { throw FloError.unexpectedValue("the view file's \"parameters\" is not a list of rows") }
        self.name = name
        self.click = click.x == -1 && click.y == -1 ? nil : click
        self.rows = try rows.map { row in
            try row.map { entry in
                guard let entry = entry as? [Any], entry.count == 3, let name = entry[0] as? String, let point = Self.point(Array(entry[1...])) else {
                    throw FloError.unexpectedValue("a parameter in the view file is not [\"name\", x, y] with a window position")
                }
                return Parameter(name: name, point: point)
            }
        }
    }

    /// Two numbers within `coordinateLimit` of the window corner, so a typing slip in a view file cannot send the mouse far off any screen.
    private static func point(_ value: Any?) -> CGPoint? {
        guard let pair = value as? [Any], pair.count == 2, let x = pair[0] as? NSNumber, let y = pair[1] as? NSNumber else { return nil }
        let point = CGPoint(x: x.doubleValue, y: y.doubleValue)
        guard abs(point.x) <= coordinateLimit, abs(point.y) <= coordinateLimit else { return nil }
        return point
    }

    /// Larger than any window, so every real position fits.
    static let coordinateLimit: CGFloat = 20_000

    // MARK: Files

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Flo Tools/Plug-In Views", directoryHint: .isDirectory)
    }

    /// The plug-in's name as view file names use it: every "/" replaced by a space, so it stays one path component. The JXA replaced only the first "/".
    static func fileStem(plugIn: String) -> String {
        plugIn.replacingOccurrences(of: "/", with: " ")
    }

    /// "EQ3 7-Band.txt" for the default view, "EQ3 7-Band-3.txt" for view 3.
    static func fileName(plugIn: String, view number: Int?) -> String {
        let stem = fileStem(plugIn: plugIn)
        return number.map { "\(stem)-\($0).txt" } ?? "\(stem).txt"
    }

    /// The view from its file, nil when there is no file, as for most plug-ins.
    static func load(plugIn: String, view number: Int?, from folder: URL = folder) throws -> PlugInView? {
        let file = folder.appending(path: fileName(plugIn: plugIn, view: number), directoryHint: .notDirectory)
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        }
        do {
            return try PlugInView(json: data)
        } catch {
            // Info, not warning: the engine logs the thrown error as the failure. This line keeps the parse detail, which the thrown error leaves out.
            Log.info(.app, "view file \(file.lastPathComponent): \(error)")
            throw FloError.couldNot("read the view file \(file.lastPathComponent)")
        }
    }

    // MARK: Moving

    /// Where the parameter cursor is: row and column, counted from 0.
    struct Position: Sendable, Equatable {
        var row: Int
        var column: Int
    }

    /// The position after moving `rows` down and `columns` right from `position`, nil before the first move. Both stay inside the view, and the column inside its row, as in the JXA, so the first move of any kind lands on the first parameter. Nil when the view has no parameter there.
    func position(after position: Position?, rows: Int, columns: Int) -> Position? {
        let start = position ?? Position(row: -1, column: -1)
        guard !self.rows.isEmpty else { return nil }
        let row = (start.row + rows).clamped(to: 0...(self.rows.count - 1))
        guard !self.rows[row].isEmpty else { return nil }
        let column = (start.column + columns).clamped(to: 0...(self.rows[row].count - 1))
        return Position(row: row, column: column)
    }

    subscript(position: Position) -> Parameter { rows[position.row][position.column] }

    // MARK: Template

    /// The text of Display Plugin View Template: the file name to save as, then a default view listing every parameter in one row with placeholder positions, as in the JXA.
    static func template(plugIn: String, parameters: [String]) -> String {
        let entries = parameters.map { "[\(jsonString($0)),0,0]" }.joined(separator: ",\n")
        return "\(fileStem(plugIn: plugIn))\n{\"view\":\"Default\", \"click\":[-1,-1], \"parameters\":[\n[\n\(entries)\n]\n]}"
    }

    /// `text` as a quoted JSON string. The JXA did not escape names; a quote, backslash or tab in a parameter name would have made the file unreadable.
    static func jsonString(_ text: String) -> String {
        // A string always serializes; the fallback only satisfies the type.
        guard let data = try? JSONSerialization.data(withJSONObject: text, options: [.fragmentsAllowed, .withoutEscapingSlashes]) else { return "\"\"" }
        return String(decoding: data, as: UTF8.self)
    }
}

extension FloFeatures {
    /// Copies the view files shipped in the app (`Contents/Resources/Plug-In Views`, copied from `reference/Plug-In Views` by `scripts/build-app.sh`) into the user's Plug-In Views folder, as the KM installer did. A file the user already has is left alone, so their own views and edits survive. Returns the names of the files copied.
    public static func installPlugInViews(from shipped: URL) throws -> [String] {
        try installPlugInViews(from: shipped, to: PlugInView.folder)
    }

    /// Into `folder`, which tests set to a temporary one.
    static func installPlugInViews(from shipped: URL, to folder: URL) throws -> [String] {
        let files = FileManager.default
        try files.createDirectory(at: folder, withIntermediateDirectories: true)
        let names = try files.contentsOfDirectory(atPath: shipped.path(percentEncoded: false)).filter { $0.hasSuffix(".txt") }.sorted()
        var copied: [String] = []
        for name in names {
            let target = folder.appending(path: name, directoryHint: .notDirectory)
            guard !files.fileExists(atPath: target.path(percentEncoded: false)) else { continue }
            try files.copyItem(at: shipped.appending(path: name, directoryHint: .notDirectory), to: target)
            copied.append(name)
        }
        return copied
    }
}

/// The loaded plug-in view and the parameter the cursor is on. Replaces the KM variables FTPluginControlParameters and FTPluginControlIndex. Loading a view, which happens whenever a plug-in window comes to front, starts over.
actor PlugInViewCursor {
    private var view: PlugInView?
    private var position: PlugInView.Position?

    /// Replaces the view, nil for a plug-in without one, and goes back to before the first parameter.
    func load(_ view: PlugInView?) {
        self.view = view
        position = nil
    }

    /// Moves and returns the parameter now under the cursor. Throws when no view is loaded.
    func move(rows: Int, columns: Int) throws -> PlugInView.Parameter {
        guard let view else { throw FloError.notFound("a plug-in view for this plug-in") }
        guard let next = view.position(after: position, rows: rows, columns: columns) else { throw FloError.notFound("a parameter in this plug-in view") }
        position = next
        return view[next]
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
