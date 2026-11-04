import Foundation
import FloEngine
import FloProTools
import FloSystem

/// The header at the top of the diagnostic log: what the developer needs to know about this Mac's setup to read the entries.
/// No hardware identifiers, serial numbers or user name.
@MainActor
enum DiagnosticHeader {
    static func text(engine: Engine, preferences: Preferences) -> String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return ([
            "Flo Tools \(version) (\(build)) diagnostic log",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "Pro Tools: \(ProToolsApp.version)",
            "VoiceOver running: \(WorkspaceEvents.isVoiceOverRunning ? "yes" : "no")",
            "Accessibility permission: \(Accessibility.isTrusted() ? "granted" : "not granted")",
            "VoiceOver automation permission: \(VoiceOver.automationPermission())",
            "Flo Tools enabled: \(engine.isEnabled ? "yes" : "no")",
            "Suspended: \(engine.suspensions.isEmpty ? "no" : engine.suspensions.map(\.reason).sorted().joined(separator: "; "))",
            "Preferences: temporary inspector \(preferences.temporaryInspector), starts with Flo Tools inspector \(preferences.startsWithInspector), timeout \(preferences.timeout) ms, hold for double press \(preferences.holdForDoublePress), hold time \(preferences.holdTime) ms",
            "Inspector: \(engine.mode.inspector ? "on" : "off")",
        ]).joined(separator: "\n") + "\n"
    }
}
