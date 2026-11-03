import Foundation
import Testing
@testable import FloSystem

/// The diagnostic log file, in a temporary folder with its own defaults so the real log is not touched.
@Suite final class LogFileTests {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("FloToolsLogTests-\(UUID().uuidString)")
    var logs: URL { root.appendingPathComponent("Logs") }
    var crashes: URL { root.appendingPathComponent("DiagnosticReports") }
    let suite = "FloToolsLogTests-\(UUID().uuidString)"

    deinit {
        try? FileManager.default.removeItem(at: root)
        UserDefaults().removePersistentDomain(forName: suite)
    }

    func makeFile(capBytes: Int = 20_000_000, keepBytes: Int = 10_000_000) -> LogFile {
        LogFile(directory: logs, crashReportDirectory: crashes, capBytes: capBytes, keepBytes: keepBytes, defaults: UserDefaults(suiteName: suite)!)
    }

    func entry(_ message: String, invocation: String? = "run1") -> LogFile.Entry {
        LogFile.Entry(date: Date(), level: .info, category: .engine, invocation: invocation, message: message)
    }

    func text(_ url: URL?) throws -> String {
        try String(contentsOf: try #require(url), encoding: .utf8)
    }

    @Test func writesHeaderThenOneLinePerEntry() throws {
        let file = makeFile()
        #expect(!file.isRecording)
        try file.start(header: "HEADER")
        #expect(file.isRecording)
        file.append(entry("S pressed -> inspector.speakToggleSolo"))
        file.append(entry("two\nlines", invocation: nil))
        let url = file.stop()
        #expect(!file.isRecording)
        let lines = try text(url).split(separator: "\n").map(String.init)
        #expect(lines.first == "HEADER")
        #expect(lines.count == 3)
        // "2026-11-02 19:02:17.931 info engine run1 message"
        #expect(lines[1].range(of: #"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3} info engine run1 S pressed -> inspector\.speakToggleSolo$"#, options: .regularExpression) != nil)
        #expect(lines[2].hasSuffix(" info engine - two\\nlines"))
    }

    @Test func resumeContinuesTheSameFile() throws {
        let first = makeFile()
        try first.start(header: "FIRST")
        first.append(entry("before relaunch"))
        first.waitForWrites()
        // A new instance with the same defaults stands in for the next launch.
        let second = makeFile()
        #expect(second.resume(header: "SECOND"))
        second.append(entry("after relaunch"))
        let contents = try text(second.stop())
        #expect(contents.contains("FIRST"))
        #expect(contents.contains("before relaunch"))
        #expect(contents.contains("Flo Tools started again while logging was on.\nSECOND"))
        #expect(contents.contains("after relaunch"))
        #expect(!makeFile().resume(header: "THIRD"), "stop clears the remembered file")
    }

    @Test func dropsOldestEntriesPastTheCap() throws {
        let file = makeFile(capBytes: 4_000, keepBytes: 1_000)
        try file.start(header: "HEADER")
        for i in 0..<200 { file.append(entry("entry \(i)")) }
        let contents = try text(file.stop())
        #expect(contents.hasPrefix("HEADER\n"))
        #expect(contents.contains("dropped"))
        #expect(contents.utf8.count < 4_000 + 200)
        #expect(contents.contains("entry 199"))
        #expect(!contents.contains("entry 0\n"))
    }

    @Test func appendsOnlyFloToolsCrashReportsFromWhileLogging() throws {
        try FileManager.default.createDirectory(at: crashes, withIntermediateDirectories: true)
        try "old crash".write(to: crashes.appendingPathComponent("FloTools-old.ips"), atomically: true, encoding: .utf8)
        // Creation dates have one-second precision on some volumes.
        Thread.sleep(forTimeInterval: 1.1)
        let file = makeFile()
        try file.start(header: "HEADER")
        try "new crash in \(NSHomeDirectory())/x".write(to: crashes.appendingPathComponent("FloTools-new.ips"), atomically: true, encoding: .utf8)
        try "other app".write(to: crashes.appendingPathComponent("Finder-new.ips"), atomically: true, encoding: .utf8)
        let contents = try text(file.stop())
        #expect(contents.contains("--- Crash report FloTools-new.ips ---\nnew crash in ~/x"))
        #expect(!contents.contains("old crash"))
        #expect(!contents.contains("other app"))
    }

    @Test func crashReportsLoseDeviceIdentifiers() {
        let report = #"{"crashReporterKey" : "AD0B08BD-1", "modelCode" : "Mac15,6", "deviceIdentifierForVendor":"02780402-2", "bootSessionUUID" : "0A12-3"}"#
        #expect(LogFile.redactingCrashReport(report) == #"{"crashReporterKey" : "redacted", "modelCode" : "Mac15,6", "deviceIdentifierForVendor":"redacted", "bootSessionUUID" : "redacted"}"#)
    }

    @Test func homePathsAreWrittenAsTilde() {
        #expect(Log.redactingHome("\(NSHomeDirectory())/Library/Logs") == "~/Library/Logs")
    }
}
