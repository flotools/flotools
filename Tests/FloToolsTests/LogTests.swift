import Foundation
import Testing
@testable import FloSystem

/// The diagnostic log file, in a temporary folder with its own defaults so the real log is not touched.
@Suite final class LogFileTests {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("FloToolsLogTests-\(UUID().uuidString)")
    var logs: URL { root.appendingPathComponent("Logs") }
    var crashes: URL { root.appendingPathComponent("DiagnosticReports") }
    let suite = TestDefaults("FloToolsLogTests")

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    /// 2026-11-07 12:00 local time.
    static let day = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 12))!

    func makeFile(capBytes: Int = 20_000_000, keepBytes: Int = 19_000_000, now: Date = day) -> LogFile {
        LogFile(directory: logs, crashReportDirectory: crashes, capBytes: capBytes, keepBytes: keepBytes, defaults: suite.defaults, now: { now })
    }

    func entry(_ message: String, invocation: String? = "run1") -> LogFile.Entry {
        LogFile.Entry(date: Date(), level: .info, category: .engine, invocation: invocation, message: message)
    }

    func text(_ url: URL?) throws -> String {
        try String(contentsOf: try #require(url), encoding: .utf8)
    }

    @Test func writesHeaderThenOneLinePerEntry() async throws {
        let file = makeFile()
        #expect(!file.isRecording)
        try await file.start(header: "HEADER")
        #expect(file.isRecording)
        file.append(entry("S pressed -> inspector.speakToggleSolo"))
        file.append(entry("two\nlines", invocation: nil))
        let url = await file.stop()
        #expect(!file.isRecording)
        let lines = try text(url).split(separator: "\n").map(String.init)
        #expect(lines.first == "HEADER")
        #expect(lines.count == 3)
        // "2026-11-02 19:02:17.931 info engine run1 message"
        #expect(lines[1].range(of: #"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\.\d{3} info engine run1 S pressed -> inspector\.speakToggleSolo$"#, options: .regularExpression) != nil)
        #expect(lines[2].hasSuffix(" info engine - two\\nlines"))
    }

    @Test func namesTheFileForTheTime() async throws {
        let file = makeFile()
        try await file.start(header: "HEADER")
        let url = await file.stop()
        #expect(url?.lastPathComponent == "Flo Tools 2026-11-07 12-00-00.log")
    }

    @Test func turningOnAgainOpensANewFile() async throws {
        let first = makeFile()
        try await first.start(header: "FIRST")
        first.append(entry("first entry"))
        let firstURL = await first.stop()
        let second = makeFile(now: Self.day.addingTimeInterval(5))
        try await second.start(header: "SECOND")
        second.append(entry("second entry"))
        let secondURL = await second.stop()
        #expect(secondURL?.lastPathComponent == "Flo Tools 2026-11-07 12-00-05.log")
        #expect(try text(secondURL).hasPrefix("SECOND\n"))
        #expect(!(try text(secondURL).contains("first entry")))
        #expect(try text(firstURL).contains("first entry"))
    }

    /// Two starts in the same second share a name; the second appends rather than erasing the first.
    @Test func aFileWithTheSameNameIsAppendedTo() async throws {
        let file = makeFile()
        try await file.start(header: "FIRST")
        file.append(entry("first entry"))
        _ = await file.stop()
        try await file.start(header: "SECOND")
        file.append(entry("second entry"))
        let lines = try text(await file.stop()).split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        #expect(lines.first == "FIRST")
        #expect(lines[1].hasSuffix("first entry"))
        #expect(lines[2] == "", "a blank line separates the sessions")
        #expect(lines[3] == "SECOND")
        #expect(lines[4].hasSuffix("second entry"))
    }

    @Test func resumeOpensANewFile() async throws {
        let first = makeFile()
        try await first.start(header: "FIRST")
        first.append(entry("before relaunch"))
        first.waitForWrites()
        // A new instance with the same defaults stands in for the next launch, a minute later.
        let second = makeFile(now: Self.day.addingTimeInterval(60))
        #expect(second.resume())
        second.append(entry("during startup"))
        second.writeHeader("SECOND")
        second.append(entry("after relaunch"))
        let url = await second.stop()
        #expect(url?.lastPathComponent == "Flo Tools 2026-11-07 12-01-00.log")
        let contents = try text(url)
        #expect(contents.hasPrefix("Flo Tools started again while logging was on.\n"))
        let startup = try #require(contents.range(of: "during startup"))
        let header = try #require(contents.range(of: "\nSECOND\n"))
        #expect(startup.upperBound <= header.lowerBound, "entries logged before the header are kept")
        #expect(contents.contains("after relaunch"))
        #expect(!contents.contains("before relaunch"))
        #expect(try text(logs.appendingPathComponent("Flo Tools 2026-11-07 12-00-00.log")).contains("before relaunch"))
        #expect(!makeFile().resume(), "stop clears the remembered state")
    }

    @Test func dropsOldestEntriesPastTheCap() async throws {
        let file = makeFile(capBytes: 4_000, keepBytes: 1_000)
        try await file.start(header: "HEADER")
        for i in 0..<200 { file.append(entry("entry \(i)")) }
        let contents = try text(await file.stop())
        #expect(contents.hasPrefix("HEADER\n"))
        #expect(contents.contains("dropped"))
        #expect(contents.utf8.count < 4_000 + 200)
        #expect(contents.contains("entry 199"))
        #expect(!contents.contains("entry 0\n"))
    }

    @Test func appendsOnlyFloToolsCrashReportsFromWhileLogging() async throws {
        try FileManager.default.createDirectory(at: crashes, withIntermediateDirectories: true)
        let old = crashes.appendingPathComponent("FloTools-old.ips")
        try "old crash".write(to: old, atomically: true, encoding: .utf8)
        // Dated a minute back rather than waiting, because creation dates have one-second precision on some volumes.
        try FileManager.default.setAttributes([.creationDate: Date(timeIntervalSinceNow: -60)], ofItemAtPath: old.path)
        let file = makeFile()
        try await file.start(header: "HEADER")
        try "new crash in \(NSHomeDirectory())/x".write(to: crashes.appendingPathComponent("FloTools-new.ips"), atomically: true, encoding: .utf8)
        try "other app".write(to: crashes.appendingPathComponent("Finder-new.ips"), atomically: true, encoding: .utf8)
        let contents = try text(await file.stop())
        #expect(contents.contains("--- Crash report FloTools-new.ips ---\nnew crash in ~/x"))
        #expect(!contents.contains("old crash"))
        #expect(!contents.contains("other app"))
    }

    @Test func crashReportsStayUnderTheCap() async throws {
        try FileManager.default.createDirectory(at: crashes, withIntermediateDirectories: true)
        let file = makeFile(capBytes: 4_000, keepBytes: 1_000)
        try await file.start(header: "HEADER")
        for i in 0..<30 { file.append(entry("entry \(i)")) }
        try String(repeating: "x", count: 10_000).write(to: crashes.appendingPathComponent("FloTools-big.ips"), atomically: true, encoding: .utf8)
        let contents = try text(await file.stop())
        #expect(contents.utf8.count <= 4_000)
        #expect(contents.hasPrefix("HEADER\n"))
        #expect(contents.contains("--- Crash report FloTools-big.ips ---"))
        #expect(contents.contains("--- Crash report cut: "))
    }

    @Test func crashReportsLoseDeviceIdentifiers() {
        let report = #"{"crashReporterKey" : "AD0B08BD-1", "modelCode" : "Mac15,6", "deviceIdentifierForVendor":"02780402-2", "bootSessionUUID" : "0A12-3"}"#
        #expect(LogFile.redactingCrashReport(report) == #"{"crashReporterKey" : "redacted", "modelCode" : "Mac15,6", "deviceIdentifierForVendor":"redacted", "bootSessionUUID" : "redacted"}"#)
    }

    @Test func homePathsAreWrittenAsTilde() {
        #expect(Log.redactingHome("\(NSHomeDirectory())/Library/Logs") == "~/Library/Logs")
    }
}
