import AppKit
import FloEngine
import FloProTools
import FloSystem

/// The header at the top of the diagnostic log: what the developer needs to know about this Mac's setup to read the entries.
/// No hardware identifiers, serial numbers or user name.
@MainActor
enum DiagnosticHeader {
    static func text(engine: MacroEngine) -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        let preferences = Preferences.load()
        let groups = engine.groups.values.sorted { $0.name < $1.name }.map { group in
            let enabled = engine.isGroupEnabled(group.id) ? "enabled" : "disabled"
            let activated = engine.isGroupActivated(group.id) ? "activated" : "deactivated"
            return "  \(group.name): \(enabled), \(activated)"
        }
        return ([
            "Flo Tools \(version) (\(build)) diagnostic log",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Pro Tools: \(ProTools.version)",
            "VoiceOver running: \(NSWorkspace.shared.isVoiceOverEnabled ? "yes" : "no")",
            "Accessibility permission: \(Accessibility.isTrusted() ? "granted" : "not granted")",
            "VoiceOver automation permission: \(VoiceOver.automationPermission())",
            "Flo Tools enabled: \(engine.isEnabled ? "yes" : "no")",
            "Preferences: temporary inspector \(preferences.temporaryInspector), starts with Flo Tools inspector \(preferences.startsWithInspector), timeout \(preferences.timeout) ms",
            "Groups:",
        ] + groups).joined(separator: "\n") + "\n"
    }
}
