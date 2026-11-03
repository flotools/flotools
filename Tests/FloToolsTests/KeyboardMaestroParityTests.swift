import Foundation
import Testing
@testable import FloMacros
@testable import FloEngine
@testable import FloProTools
@testable import FloSystem

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
        "inspector.decreaseInstrumentVolume": "213EE66F-86AC-462B-BB2C-3E3F0BAEE9AE",
        "inspector.decreaseVolume": "387783D0-17E0-4868-97BC-FC20712BEBDF",
        "inspector.increaseInstrumentVolume": "03CF90B2-C388-4F4F-9550-2D74C570597B",
        "inspector.increaseVolume": "5DA65AC1-5A53-4003-844E-75273F49916C",
        "inspector.speakAndSelectTrackShowRightClickMenu": "ADBCEFDF-6ADF-47B1-8926-F0A37E2B81C1",
        "inspector.speakEditComments": "BC36AF98-3D2F-45D4-920E-7F61A03AD411",
        "inspector.speakResetInstrumentPan": "6165EE6F-CFDB-4F95-B309-C0BE011BA511",
        "inspector.speakResetInstrumentVolume": "72146C65-FD10-4EF8-87E9-AF354AC7C72C",
        "inspector.speakResetPan": "B7196BF6-FE59-4DF8-AE2F-7603E8569D3B",
        "inspector.speakResetPeakMeter": "1C6D9619-0269-4AB1-A64F-799FDEA688D5",
        "inspector.speakResetVolumeFader": "76B6802A-B448-4CD7-BBEF-AD8A550315FD",
        "inspector.speakSelectAutomationMode": "7E24E71D-E197-4D9D-B501-673C0119CF44",
        "inspector.speakSelectElasticAudioPlugin": "613C6AFB-613B-4CCB-8EE0-7CFED22C14E3",
        "inspector.speakSelectGroup": "32214BFE-5ADF-41CF-8DE2-2E20A2FEABFC",
        "inspector.speakSelectInstrumentInput": "8733DDFD-E6DC-499A-9569-16CD651605B6",
        "inspector.speakSelectInstrumentOutput": "03BC2EC0-31FA-4732-9189-8AFD106AC795",
        "inspector.speakSelectPlaylist": "366D9BB1-8DE8-4A77-BEF2-4C69C1878B03",
        "inspector.speakSelectTimebase": "87F99400-977E-4A95-9FD5-3918BEAF93CE",
        "inspector.speakSelectTrackInput": "7A7404B4-51E6-4C3F-9ED0-36F38FF9277D",
        "inspector.speakSelectTrackOutput": "AC68B729-FACE-40B3-B44E-75D060D4E6F1",
        "inspector.speakSelectTrackView": "6A53AF54-B897-4B37-9CF8-5F15D19B1CE4",
        "inspector.speakToggleFreezeStatus": "DF394380-80A1-4B45-950F-8EFCB3C940A3",
        "inspector.trackOptionsMenu": "93C746D3-9062-423E-857F-E95F06F6E300",
        "inspector.speakOpenSendB": "F9ED77CC-B335-4608-BDBE-C560B3AC30F9",
        "inspector.speakToggleMute": "708123E8-4C4A-4AF1-B102-9076D922CFD9",
        "inspector.speakToggleRecordState": "800A0740-6F7A-46F0-BDCF-B2481B01FB02",
        "inspector.speakToggleInputMonitor": "6B397B91-A570-47FD-91B7-807C30511E69",
        "inspector.speakToggleInstrumentMute": "D614E7B9-1A9B-4A7A-9100-D57C38D7B45A",
        "inspector.assignInsertA": "A913784B-20F4-465C-BEEE-060DB4CE1B08",
        "inspector.assignInsertB": "E7C506D4-F2CF-4032-BE01-B7A2DBDE4098",
        "inspector.assignInsertC": "EF605A53-014F-4FD5-9C1B-14E2220383C1",
        "inspector.assignInsertD": "02C3CC1C-9126-44D2-88D2-0AF962790972",
        "inspector.assignInsertE": "2056F943-E789-4487-9013-97A3C9C521E6",
        "inspector.assignInsertF": "E842D842-DD6A-4253-890B-E3F4D9C04D22",
        "inspector.assignInsertG": "F2B12D67-8618-41ED-AEB7-0A77C8576CC1",
        "inspector.assignInsertH": "FCC1BB1D-D756-45E4-BCD7-DC142F33126B",
        "inspector.assignInsertI": "9A62399E-80C2-4784-94F1-C32CAE5FCF92",
        "inspector.assignInsertJ": "9D34C1E5-DB04-4BA4-A6E5-0AF3EA0213D7",
        "inspector.assignSendA": "93157301-7A3A-431A-BAD4-0F814DF57840",
        "inspector.assignSendB": "A5CB767B-E3D8-4E77-B282-E24B68CB6E7E",
        "inspector.assignSendC": "86933FB3-55A5-43C3-A319-E0EFB4DFEB57",
        "inspector.assignSendD": "37E30067-D8FD-41C8-BB5F-FEDFDA9A7A7A",
        "inspector.assignSendE": "853A4B13-CD0A-408B-8532-C8A77D2DA7DB",
        "inspector.assignSendF": "F3E88078-4DA4-45ED-8333-D9B756C5C296",
        "inspector.assignSendG": "6063BA2E-6C29-4E66-8458-96DF2323E14F",
        "inspector.assignSendH": "5178C660-214B-4F18-B46C-3EC9E66EB955",
        "inspector.assignSendI": "3047752C-0899-4962-A819-3797E6095707",
        "inspector.assignSendJ": "DD561616-0FF2-4F82-9A8B-1BB3444BE045",
        "inspector.speakOpenInsertA": "F08671D6-BAA1-455E-8AE1-E9908063345A",
        "inspector.speakOpenInsertB": "43E15266-F1C0-4131-B6D0-3A068A08288D",
        "inspector.speakOpenInsertC": "E100309E-77A7-4BDC-9775-11A0EF423C3B",
        "inspector.speakOpenInsertD": "6F1354E9-E864-4C26-B1F6-DAA75E6538A3",
        "inspector.speakOpenInsertE": "EEC95BC4-31F9-497F-9679-4BF31E87066F",
        "inspector.speakOpenInsertF": "F4F9AA33-3B0D-4B09-A1EB-0BEC1C57D2B7",
        "inspector.speakOpenInsertG": "5094EA2B-D33E-4F60-A490-E36231A30FFF",
        "inspector.speakOpenInsertH": "9DEAD364-0562-46AF-BE1E-62812AF81B9C",
        "inspector.speakOpenInsertI": "C0A25523-D14C-4639-928F-6CE252F3EC50",
        "inspector.speakOpenInsertJ": "3F5059EA-018E-4AAA-AFC9-BE6B58E79152",
        "inspector.speakOpenSendA": "5C041461-3A68-400D-B8A1-B689CB38D6F8",
        "inspector.speakOpenSendC": "4C032CCB-AECD-4C7C-94CB-6B231222BEC7",
        "inspector.speakOpenSendD": "2BABC2F0-1F23-4F38-BE62-547445FDBECF",
        "inspector.speakOpenSendE": "1E895B5D-9C60-49DE-AF50-4A0CB186C7BD",
        "inspector.speakOpenSendF": "5FBCBDCB-48DA-449F-B41E-5946D8C56951",
        "inspector.speakOpenSendG": "5444DA62-4082-472A-B3B5-B104996A4346",
        "inspector.speakOpenSendH": "D1E605F3-8712-49B4-866C-96FD0EBC1159",
        "inspector.speakOpenSendI": "E5A4BF4F-8338-4E18-892A-6503E719FE84",
        "inspector.speakOpenSendJ": "0B0F935C-CEB5-40E5-87C7-2E95F304B4D2",
        "floTools.speakSoloedTracksUnsoloAllTracks": "2727205D-51F2-49D2-B1B0-66BA8D4D6F06",
        "inspector.speakToggleSolo": "57957B28-6D66-4BEF-85B9-48406E95FB18",
        "inspector.panRightOnMonoLeftChannel": "38AC5CB1-9C5F-4973-B8D1-20259CF38989",
        "inspector.panLeftOnMonoLeftChannel": "9C149078-8675-401D-9CD7-E1457E482328",
        "inspector.panRightOnRightChannel": "7549F3CC-362E-4A2A-AB47-9CA0F30F7BB4",
        "inspector.panLeftOnRightChannel": "A22F2199-FA1E-480D-AB0C-87DF9159B485",
        "inspector.panInstrumentRight": "AC85B840-27F7-4476-9EC2-9B25E615052D",
        "inspector.panInstrumentLeft": "30F5DC4E-61A4-415A-8E44-1465EFD13573",
        "floTools.toggleInspector": "8F157FEB-069E-465B-9AA5-92C4A59D23C4",
        "floTools.toggleTemporaryInspector": "E63048EB-FBD0-41A9-A4C7-8922216F11D3",
        "floTools.nextTrackViewOnSelectedTracks": "C035969D-E50C-4671-AFBA-CFF648FD3A48",
        "floTools.previousTrackViewOnSelectedTracks": "1FF40247-C860-471D-BACC-DFB16C9A65A1",
        "floTools.floToolsPreferences": "4958F0C0-2806-4D1F-A1DA-C0124F1AD759",
        "selectedTab.tab1": "8ADB9D7E-7928-4685-9B03-951B883F29A4",
        "selectedTab.tab2": "656463B9-2F24-4E3C-B064-0EDD916AF0B6",
        "selectedTab.tab3": "1480A1D4-E82F-4F37-A2FC-C9A22E73BDB8",
        "selectedTab.tab4": "08CDB9D4-F8C7-483D-A806-FA5C622A04C7",
        "selectedTab.tab5": "C7AA19FE-CA82-48A7-9421-E43298342E17",
        "selectedTab.tab6": "5D9F693F-572D-409C-9AB5-DF32ECE8410B",
        "selectedTab.tab7": "8A85443B-00D3-4A66-9677-B842130375C7",
        "selectedTab.tab8": "08026A87-90D9-46B7-8992-618EDA5DBDDF",
        "selectedTab.tab9": "169C20E8-AC0C-4348-93C0-88B154BE93BB",
        "fadeIn.nextFadeInShapeCurve": "D81E6BA6-605C-4C85-BCC8-5623589CBB97",
        "fadeIn.nextFadeInShapeParameter": "91510FDD-7E7A-4248-A8E6-1513BFE43F1A",
        "fadeIn.nextLinkOutIn": "5F66BB03-846C-494A-8DAB-0350BB484C64",
        "fadeIn.previousFadeInShapeCurve": "B288A7C5-A16E-46DE-A3A6-D7DEF0B74112",
        "fadeIn.previousFadeInShapeParameter": "B764E305-995D-4089-926B-02D32AEB4DC9",
        "fadeIn.previousLinkOutIn": "2CA006EB-DE0E-44A7-85D6-744EB715FD8B",
        "fadeOut.nextFadeOutShapeCurve": "7C50FFBD-7E81-45A3-AF03-8F28A17D5AAD",
        "fadeOut.nextFadeOutShapeParameter": "C2EC2E94-4907-4385-8A8C-B1657F0AB0F9",
        "fadeOut.nextLinkOutIn": "32D43CC4-D724-46B2-9008-953A5E62722E",
        "fadeOut.previousFadeOutShapeCurve": "B54D3D63-BECF-4D96-A354-2CE80E858AB3",
        "fadeOut.previousFadeOutShapeParameter": "421B1B80-21EE-4142-951E-750750EFEBDC",
        "fadeOut.previousLinkOutIn": "FCD20C29-0233-456B-85D5-5CB9BAE573D9",
        "crossfade.nextCrossfadeInShapeCurve": "3711FFBB-2395-4F41-A46B-0154CC2D456A",
        "crossfade.nextCrossfadeInShapeParameter": "92BC8EDB-B6A8-4586-A9F9-B53CCE08FA43",
        "crossfade.nextCrossfadeOutShapeCurve": "F6E24227-3232-4EEC-ACEC-965D9B9C0173",
        "crossfade.nextLinkOutIn": "82B4E09F-0330-4030-979C-9CF9C89586D3",
        "crossfade.nextCrossfadeOutShapeParameter": "0890D22E-EDF7-4803-B20F-14E72720D89A",
        "crossfade.previousCrossfadeInShapeCurve": "C708B32F-9E32-43C7-B310-BB80C7E77E92",
        "crossfade.previousCrossfadeInShapeParameter": "1FA44547-5F78-45E4-8703-51DFCC118791",
        "crossfade.previousCrossfadeOutShapeCurve": "B0A4EA1C-3FB3-4AA8-BC96-0938DC552357",
        "crossfade.previousCrossfadeOutShapeParameter": "0D658DC8-D474-4E0D-A791-C942F9C98752",
        "crossfade.previousLinkOutIn": "A47F3FB3-EDB7-4C6C-9F52-BF573DDD95B9",
        "batchFades.nextCrossfadeInShapeCurve": "FD840406-E744-441C-BE7C-01AD00774D85",
        "batchFades.nextCrossfadeInShapeParameter": "420ECF4B-CD66-4F2A-BBCA-9B9B1CFC5714",
        "batchFades.nextCrossfadeLink": "D65B8F56-D100-44AA-8D9D-10CC96B4F3FE",
        "batchFades.nextCrossfadeOutShapeCurve": "1AB29A21-663B-4957-A19C-CE4F7DFA89F4",
        "batchFades.nextCrossfadeOutShapeParameter": "53007920-D2C6-490A-B84D-7E1D738E50BC",
        "batchFades.nextFadeInShapeCurve": "DD93F80A-1026-4B63-B44E-BAD89F2CB21C",
        "batchFades.nextFadeInShapeParameter": "F5E52450-3C8E-45BE-BE81-AD4DCC43EC49",
        "batchFades.nextFadeOutShapeCurve": "9A9C99B0-A7E3-452D-ABA1-CF719BBF1400",
        "batchFades.nextFadeOutShapeParameter": "C789F858-DDF6-49AA-966A-E5BA0800BC5F",
        "batchFades.nextInSlope": "2BBCE161-2778-4445-A106-A781732D1637",
        "batchFades.nextOutSlope": "5EBD25A4-EBAE-42ED-AC2D-93F1EE3B7228",
        "batchFades.previousCrossfadeInShapeCurve": "894B5278-E347-4E8A-9202-A8154FCF8CAC",
        "batchFades.previousCrossfadeInShapeParameter": "76AC612A-3F5C-4B43-A1E8-BB46E27A08CA",
        "batchFades.previousCrossfadeLink": "24FFACB2-3C41-4203-9F9B-3035B6C8FF5D",
        "batchFades.previousCrossfadeOutShapeCurve": "0834989E-3119-4CF5-8675-3D4125FC918F",
        "batchFades.previousCrossfadeOutShapeParameter": "C0BD46D8-CB73-4DFD-9847-A4B68404DC98",
        "batchFades.previousFadeInShapeCurve": "456BB4D3-3257-4570-902A-B5148D91D46D",
        "batchFades.previousFadeInShapeParameter": "348D1F52-5AA6-4210-AC19-CA6BEA9B0A87",
        "batchFades.previousFadeOutShapeCurve": "B4D8720E-149E-49DC-B948-027A541C777E",
        "batchFades.previousFadeOutShapeParameter": "E8398D3F-1A17-44F1-A7CB-FF7F521A97E6",
        "batchFades.previousInSlope": "5A5EFB2E-6051-41EF-8521-56BAAC3828D2",
        "batchFades.previousOutSlope": "BCD27252-0B06-4A87-BB17-A1DAAC5357C4",
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
        #expect(Set(FloMacros.all().map(\.id)) == Set(Self.macroOrigins.keys), "every macro needs an entry in macroOrigins")
        for macro in FloMacros.all() where Self.changedOnPurpose[macro.id] == nil {
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
