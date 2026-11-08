import Foundation

/// A macOS privacy list that Flo Tools needs to be allowed in, named as `tccutil` names it.
public enum PrivacyPermission: String, Sendable {
    case accessibility = "Accessibility"
    case appleEvents = "AppleEvents"
    /// Every privacy list at once.
    case all = "All"

    /// Clears this app's recorded answer, so macOS asks again instead of keeping a refusal, or an entry left from an earlier signature that shows as allowed but does not work.
    /// There is no public API for this; `tccutil` resets an unsandboxed app's own entries without administrator rights (tested 2026-11-07, J-306). For `appleEvents` it clears the answers for every app Flo Tools sends Apple events to, which today is only VoiceOver.
    /// Blocks until `tccutil` exits, which takes a few milliseconds; call it off the main actor.
    public func resetOwnAnswer() throws {
        guard let bundleID = Bundle.main.bundleIdentifier else { throw FloError.couldNot("reset the \(rawValue) permission: the app has no bundle identifier") }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", rawValue, bundleID]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        do {
            try process.run()
        } catch {
            throw FloError.couldNot("run tccutil to reset the \(rawValue) permission: \(error.localizedDescription)")
        }
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FloError.couldNot("reset the \(rawValue) permission: tccutil exited with \(process.terminationStatus): \(text)")
        }
        Log.info(.app, "reset the \(rawValue) permission of \(bundleID)")
    }
}
