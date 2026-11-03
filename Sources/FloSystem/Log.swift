import Foundation
import os

/// The part of Flo Tools an entry comes from. Also the unified log category.
public enum LogCategory: String, Sendable, CaseIterable {
    case app, engine, context, hotkeys, accessibility, voiceover, preferences, log
}

public enum LogLevel: String, Sendable {
    case debug, info, warning, error
}

/// The one logger. All logging goes through here.
///
/// Warnings and errors always go to the unified log (subsystem `com.chikim.FloTools`). While the user has turned on the diagnostic log, every entry also goes to a file in `~/Library/Logs/Flo Tools/` that they can send to the developer. See "Diagnostic log" in `AGENTS.md` for what may and may not be logged.
public enum Log {
    /// The current macro run. The engine sets it around each run; tasks started by the run inherit it, so every line a run causes carries the same ID.
    @TaskLocal public static var invocation: String?

    public static func debug(_ category: LogCategory, _ message: @autoclosure () -> String) {
        write(.debug, category, message)
    }

    public static func info(_ category: LogCategory, _ message: @autoclosure () -> String) {
        write(.info, category, message)
    }

    public static func warning(_ category: LogCategory, _ message: @autoclosure () -> String) {
        write(.warning, category, message)
    }

    public static func error(_ category: LogCategory, _ message: @autoclosure () -> String) {
        write(.error, category, message)
    }

    /// Time since `start`, for entries such as "say ... (35 ms)".
    public static func elapsed(since start: ContinuousClock.Instant) -> String {
        let duration = ContinuousClock.now - start
        let ms = Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1e15
        return "\(Int(ms.rounded())) ms"
    }

    // MARK: Diagnostic log file

    /// Whether entries are being written to the diagnostic log file.
    public static var isRecording: Bool { file.isRecording }

    /// Starts a new log file that begins with `header`, and remembers across launches that logging is on.
    public static func startRecording(header: String) throws {
        try file.start(header: header)
    }

    /// If logging was on when Flo Tools last quit or crashed, continues the same file, adding `header` again. Returns whether it did.
    @discardableResult
    public static func resumeRecording(header: String) -> Bool {
        file.resume(header: header)
    }

    /// Stops logging, appends Flo Tools crash reports written while it was on, and returns the finished file.
    public static func stopRecording() -> URL? {
        file.stop()
    }

    // MARK: Writing

    /// Process-wide by nature: every part of the app logs, and there is one file.
    private static let file = LogFile()
    private static let unified: [LogCategory: Logger] = Dictionary(uniqueKeysWithValues:
        LogCategory.allCases.map { ($0, Logger(subsystem: "com.chikim.FloTools", category: $0.rawValue)) })

    private static func write(_ level: LogLevel, _ category: LogCategory, _ message: () -> String) {
        let important = level == .warning || level == .error
        let recording = file.isRecording
        guard important || recording else { return }
        let text = redactingHome(message())
        if important, let logger = unified[category] {
            // Private: the text can hold track names, which the owner approved only for the opt-in file.
            logger.log(level: level == .error ? .error : .default, "\(text, privacy: .private)")
        }
        if recording {
            file.append(LogFile.Entry(date: Date(), level: level, category: category, invocation: invocation, message: text))
        }
    }

    /// Home paths are written as `~`, so the user name does not appear in the log.
    static func redactingHome(_ text: String) -> String {
        text.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

/// The diagnostic log file. Writes happen on a serial background queue so callers never wait for the disk.
///
/// Mutable state is owned by `queue`, except the recording flag, which callers read on every log call and is behind a lock. `UserDefaults` is thread-safe.
final class LogFile: @unchecked Sendable {
    struct Entry: Sendable {
        let date: Date
        let level: LogLevel
        let category: LogCategory
        let invocation: String?
        let message: String
    }

    /// UserDefaults keys that keep logging on across launches.
    private static let fileKey = "diagnosticLogFile"
    private static let startedKey = "diagnosticLogStarted"

    private let directory: URL
    private let crashReportDirectory: URL
    /// When the file grows past `capBytes`, the oldest entries are dropped down to `keepBytes`.
    private let capBytes: Int
    private let keepBytes: Int
    /// Remembers the open file across launches. `UserDefaults` is thread-safe.
    private let defaults: UserDefaults

    private let recording = OSAllocatedUnfairLock(initialState: false)
    private let queue = DispatchQueue(label: "com.chikim.FloTools.log")
    private var handle: FileHandle?
    private var url: URL?
    private var size = 0
    /// This launch's header, kept so it stays at the top when old entries are dropped.
    private var header = ""
    private let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    /// The defaults are the real locations and a cap of about 20 MB; tests pass their own.
    init(
        directory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Flo Tools"),
        crashReportDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports"),
        capBytes: Int = 20_000_000,
        keepBytes: Int = 10_000_000,
        defaults: UserDefaults = .standard
    ) {
        self.directory = directory
        self.crashReportDirectory = crashReportDirectory
        self.capBytes = capBytes
        self.keepBytes = keepBytes
        self.defaults = defaults
    }

    var isRecording: Bool { recording.withLock { $0 } }

    func start(header: String) throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let url = directory.appendingPathComponent("Flo Tools \(formatter.string(from: Date())).log")
        try queue.sync {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: url)
            try open(url, header: header)
        }
        defaults.set(url.path, forKey: Self.fileKey)
        defaults.set(Date(), forKey: Self.startedKey)
    }

    func resume(header: String) -> Bool {
        guard let path = defaults.string(forKey: Self.fileKey) else { return false }
        let url = URL(fileURLWithPath: path)
        do {
            try queue.sync {
                if !FileManager.default.fileExists(atPath: path) {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try Data().write(to: url)
                }
                try open(url, header: "\nFlo Tools started again while logging was on.\n" + header)
            }
            return true
        } catch {
            Log.error(.log, "could not continue the log file \(path): \(error)")
            defaults.removeObject(forKey: Self.fileKey)
            return false
        }
    }

    func stop() -> URL? {
        guard isRecording else { return nil }
        let started = defaults.object(forKey: Self.startedKey) as? Date ?? .distantPast
        defaults.removeObject(forKey: Self.fileKey)
        defaults.removeObject(forKey: Self.startedKey)
        recording.withLock { $0 = false }
        return queue.sync {
            appendCrashReports(since: started)
            try? handle?.close()
            handle = nil
            defer { url = nil }
            return url
        }
    }

    func append(_ entry: Entry) {
        queue.async {
            self.write(self.format(entry))
            if self.size > self.capBytes { self.dropOldEntries() }
        }
    }

    /// Returns when every entry appended so far is written. Tests use it where a real relaunch would have ended the old process first.
    func waitForWrites() {
        queue.sync {}
    }

    // MARK: On the queue

    private func open(_ url: URL, header: String) throws {
        let handle = try FileHandle(forWritingTo: url)
        size = Int(try handle.seekToEnd())
        self.handle = handle
        self.url = url
        self.header = header
        write(header + "\n")
        recording.withLock { $0 = true }
    }

    private func write(_ text: String) {
        guard let handle else { return }
        let data = Data(text.utf8)
        do {
            try handle.write(contentsOf: data)
            size += data.count
        } catch {
            // Logging the failure to the file would fail the same way.
            Logger(subsystem: "com.chikim.FloTools", category: LogCategory.log.rawValue).error("log file write failed: \(error, privacy: .public)")
        }
    }

    /// One line per entry: timestamp, level, category, invocation ID, message. Line breaks in the message are written as "\n".
    private func format(_ entry: Entry) -> String {
        let message = entry.message.replacingOccurrences(of: "\n", with: "\\n")
        return "\(timestamp.string(from: entry.date)) \(entry.level.rawValue) \(entry.category.rawValue) \(entry.invocation ?? "-") \(message)\n"
    }

    /// Rewrites the file as this launch's header, a note, and the newest `keepBytes` of entries.
    private func dropOldEntries() {
        guard let url, let handle else { return }
        do {
            try handle.close()
            let data = try Data(contentsOf: url)
            var tail = data.suffix(keepBytes)
            if let newline = tail.firstIndex(of: UInt8(ascii: "\n")) { tail = tail[(newline + 1)...] }
            let note = format(Entry(date: Date(), level: .info, category: .log, invocation: nil, message: "dropped \(data.count - tail.count) bytes of older entries to stay under \(capBytes) bytes"))
            var rewritten = Data((header + "\n" + note).utf8)
            rewritten.append(tail)
            try rewritten.write(to: url, options: .atomic)
            let reopened = try FileHandle(forWritingTo: url)
            size = Int(try reopened.seekToEnd())
            self.handle = reopened
        } catch {
            Logger(subsystem: "com.chikim.FloTools", category: LogCategory.log.rawValue).error("could not shorten the log file: \(error, privacy: .public)")
            self.handle = try? FileHandle(forWritingTo: url)
            _ = try? self.handle?.seekToEnd()
        }
    }

    /// Flo Tools crash reports created since logging was turned on, appended in full.
    private func appendCrashReports(since started: Date) {
        let keys: [URLResourceKey] = [.creationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: crashReportDirectory, includingPropertiesForKeys: keys)) ?? []
        let reports = files.filter { file in
            let created = (try? file.resourceValues(forKeys: Set(keys)))?.creationDate ?? .distantPast
            return file.lastPathComponent.hasPrefix("FloTools") && created >= started
        }
        for report in reports.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let text = try? String(contentsOf: report, encoding: .utf8) else { continue }
            write("\n--- Crash report \(report.lastPathComponent) ---\n" + Self.redactingCrashReport(text) + "\n")
        }
    }

    /// Keys in a macOS crash report whose values identify this Mac. The rest (model, OS, the stack) is what the developer needs.
    static let identifyingCrashReportKeys = ["crashReporterKey", "deviceIdentifierForVendor", "bootSessionUUID"]

    static func redactingCrashReport(_ text: String) -> String {
        let keys = identifyingCrashReportKeys.joined(separator: "|")
        let redacted = text.replacingOccurrences(of: #"("(\#(keys))"\s*:\s*)"[^"]*""#, with: "$1\"redacted\"", options: .regularExpression)
        return Log.redactingHome(redacted)
    }
}
