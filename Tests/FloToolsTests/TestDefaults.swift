import Foundation

/// A throwaway UserDefaults suite, so tests never touch the user's settings. Removed when this is released.
final class TestDefaults {
    let name: String
    let defaults: UserDefaults

    init(_ prefix: String) {
        name = "\(prefix)-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
    }

    deinit {
        UserDefaults().removePersistentDomain(forName: name)
        // removePersistentDomain leaves the suite's file with its values (checked on macOS 27, 2026-11-03), so the file is deleted too.
        let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/\(name).plist")
        try? FileManager.default.removeItem(at: file)
    }
}
