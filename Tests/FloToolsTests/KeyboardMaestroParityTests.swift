import Foundation
import Testing
@testable import FloMacros
@testable import FloToolsCore

/// Checks the Swift macros against the retired Keyboard Maestro version, `reference/Flo Tools.kmmacros`, so ports keep their hotkeys and conditions.
/// The Keyboard Maestro UIDs live only here. A deliberate change from the KM version goes in `changedOnPurpose` with the reason.
@MainActor @Suite struct KeyboardMaestroParityTests {
    /// Swift group to KM group UID.
    static let groupOrigins: [MacroGroupID: String] = [
        .floTools: "B7E0E6A9-B857-4443-876A-DF90D29C080E",
        .inspector: "A873DB58-32B1-4730-B0D4-9C89056CB5F7",
        .global: "FEA49FEF-1551-453B-9E90-02A376C079B6",
        .selectedTab: "88C41276-86DC-4A29-AA13-EF7B6B8B0FE1",
        .plugin: "0253756E-75BD-4957-8756-3AEE9A2854D8",
        .audioSuite: "5FE46DF8-CE3D-4514-8D88-C04914589DCF",
        .fadeOut: "E6F510E8-6551-4EB8-98B6-8BEC96C2E4AD",
        .fadeIn: "47666470-7A3F-4690-AF7A-122F856786F5",
        .batchFades: "00DE7329-102E-4CC6-BB82-F7BA11CABCE6",
        .crossfade: "92216429-D149-4CEE-9A40-426919A22530",
    ]

    /// Swift macro to the KM macro it was ported from. Every macro needs an entry; a new macro with no KM original maps to nil.
    static let macroOrigins: [MacroID: String?] = [
        "inspector.speakOpenSendB": "F9ED77CC-B335-4608-BDBE-C560B3AC30F9",
        "floTools.speakSoloedTracksUnsoloAllTracks": "2727205D-51F2-49D2-B1B0-66BA8D4D6F06",
    ]

    /// Macros whose triggers, group or default state differ from KM on purpose, with the reason.
    static let changedOnPurpose: [MacroID: String] = [:]

    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    struct KMGroup {
        let enabled: Bool
        let bundleIDs: [String]
        let title: TitleCondition
    }

    struct KMMacro {
        let group: String
        let enabled: Bool
        let triggers: [MacroTrigger]
    }

    /// The export's groups and macros by UID.
    static func loadExport() throws -> (groups: [String: KMGroup], macros: [String: KMMacro]) {
        let data = try Data(contentsOf: root.appendingPathComponent("reference/Flo Tools.kmmacros"))
        let records = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]])
        var groups: [String: KMGroup] = [:]
        var macros: [String: KMMacro] = [:]
        for record in records {
            let groupUID = try #require(record["UID"] as? String)
            let targeting = record["Targeting"] as? [String: Any]
            let apps = targeting?["Targeting"] as? String == "Included" ? targeting?["TargetingApps"] as? [[String: Any]] ?? [] : []
            let titleText = record["FocussedWindowTitle"] as? String ?? ""
            let title: TitleCondition = switch (record["FocussedWindowConditionType"] as? String, titleText.isEmpty) {
            case (_, true): .any
            case ("TitleIs", _): .is(titleText)
            case ("TitleContains", _): .contains(titleText)
            default: .matches(titleText)
            }
            groups[groupUID] = KMGroup(enabled: record["IsActive"] as? Bool ?? true, bundleIDs: apps.compactMap { $0["BundleIdentifier"] as? String }, title: title)
            for macro in record["Macros"] as? [[String: Any]] ?? [] {
                let uid = try #require(macro["UID"] as? String)
                let triggers = try (macro["Triggers"] as? [[String: Any]] ?? []).map(trigger)
                macros[uid] = KMMacro(group: groupUID, enabled: macro["IsActive"] as? Bool ?? true, triggers: triggers)
            }
        }
        return (groups, macros)
    }

    static func trigger(_ t: [String: Any]) throws -> MacroTrigger {
        switch t["MacroTriggerType"] as? String {
        case "HotKey":
            let combo = KeyCombo(keyCode: try #require(t["KeyCode"] as? UInt32), modifiers: try #require(t["Modifiers"] as? UInt32))
            return .hotKey(combo, t["FireType"] as? String == "Released" ? .released : .pressed)
        case "FocussedWindow":
            let changes: [String: MacroTrigger.FocusedWindowChange] = ["FocussedWindowChanges": .focusChanges, "FocussedWindowTitleChanges": .titleChanges, "FocussedWindowsTitleChanged": .focusedWindowRetitled]
            return .focusedWindow(try #require(changes[t["ChangeType"] as? String ?? ""]))
        case "Application":
            let bundleID = try #require((t["Application"] as? [String: Any])?["BundleIdentifier"] as? String)
            return .application(t["FireType2"] as? String == "Quit" ? .quit : .launched, bundleID: bundleID)
        case "StatusMenu":
            return .statusMenu
        case let other:
            Issue.record("unknown trigger type \(other ?? "nil")")
            return .statusMenu
        }
    }

    /// Order-independent comparison of trigger lists.
    static func sorted(_ triggers: [MacroTrigger]) -> [String] {
        triggers.map { String(describing: $0) }.sorted()
    }

    @Test func groupsMatchKeyboardMaestro() throws {
        let export = try Self.loadExport()
        #expect(Set(FloMacros.groups.map(\.id)) == Set(Self.groupOrigins.keys))
        for group in FloMacros.groups {
            let km = try #require(Self.groupOrigins[group.id].flatMap { export.groups[$0] }, "no KM group for \(group.id)")
            #expect(group.enabledByDefault == km.enabled, "\(group.id)")
            #expect(group.bundleIDs == km.bundleIDs, "\(group.id)")
            #expect(group.title == km.title, "\(group.id)")
        }
    }

    @Test func macrosMatchKeyboardMaestro() throws {
        let export = try Self.loadExport()
        let kmGroupToSwift = Dictionary(uniqueKeysWithValues: Self.groupOrigins.map { ($0.value, $0.key) })
        #expect(Set(FloMacros.all.map(\.id)) == Set(Self.macroOrigins.keys), "every macro needs an entry in macroOrigins")
        for macro in FloMacros.all where Self.changedOnPurpose[macro.id] == nil {
            guard let uid = Self.macroOrigins[macro.id] ?? nil else { continue }
            let km = try #require(export.macros[uid], "no KM macro \(uid) for \(macro.id)")
            #expect(kmGroupToSwift[km.group] == macro.group, "\(macro.id) group")
            #expect(macro.enabledByDefault == km.enabled, "\(macro.id) enabled")
            #expect(Self.sorted(macro.triggers) == Self.sorted(km.triggers), "\(macro.id) triggers")
        }
    }

    /// The "Ported" column of reference/macros/INDEX.md says "yes" exactly for the ported macros.
    @Test func indexMarksPortedMacros() throws {
        let index = try String(contentsOf: Self.root.appendingPathComponent("reference/macros/INDEX.md"), encoding: .utf8)
        var marked = Set<String>()
        for line in index.split(separator: "\n") {
            let cells = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            // "| Group | Macro | Trigger | Enabled | UID | Ported |" splits into 8 cells, the first and last empty.
            if cells.count == 8, cells[6] == "yes" { marked.insert(cells[5]) }
        }
        #expect(marked == Set(Self.macroOrigins.values.compactMap { $0 }))
    }
}
