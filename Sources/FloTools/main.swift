import AppKit
import FloSystem

/// Other copies of Flo Tools started before this one, such as a development build and the one in Applications.
/// Only older copies count, so two copies launched together cannot quit each other.
func olderCopies() -> [NSRunningApplication] {
    guard let bundleID = Bundle.main.bundleIdentifier else { return [] }
    let me = NSRunningApplication.current
    let myStart = me.launchDate ?? Date()
    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter { other in
        guard other.processIdentifier != me.processIdentifier, !other.isTerminated else { return false }
        let otherStart = other.launchDate ?? .distantPast
        return otherStart < myStart || (otherStart == myStart && other.processIdentifier < me.processIdentifier)
    }
}

/// Spins the run loop, which updates `isTerminated`, until every copy has quit or the deadline passes.
func waitUntilQuit(_ copies: [NSRunningApplication], seconds: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(seconds)
    while copies.contains(where: { !$0.isTerminated }), Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    return copies.allSatisfy(\.isTerminated)
}

/// Two copies would both take every hotkey. The newly launched copy is the one the user wants, so it asks the
/// older ones to quit (they stop cleanly and log it), and force-quits any that do not quit within 3 seconds.
/// Returns false if an older copy is still running, and this copy must not start.
func quitOlderCopies() -> Bool {
    let copies = olderCopies()
    guard !copies.isEmpty else { return true }
    copies.forEach { $0.terminate() }
    if waitUntilQuit(copies, seconds: 3) { return true }
    copies.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
    return waitUntilQuit(copies, seconds: 2)
}

// Before the log resumes, so the older copy has written its last entries and closed the file first.
guard quitOlderCopies() else { exit(1) }

// First, before the delegate loads the preferences, so a relaunch while logging is on keeps every startup entry.
let resumedLog = Log.resumeRecording()
let app = NSApplication.shared
let delegate = AppDelegate(resumedLog: resumedLog)
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
