import Testing
@testable import FloMacros
@testable import FloEngine
@testable import FloProTools

@Suite struct ProToolsWindowKindTests {
    /// Titles and their kind, including the ones that fit two descriptions.
    static let titles: [(String, ProToolsWindowKind)] = [
        ("Mix: I Trust", .mix),
        ("Edit: I Trust", .edit),
        ("mix: lower case", .mix),
        ("Mix: Dashboard", .mix),
        ("Edit: Preferences", .edit),
        ("Mix: Audio Suite: odd session name", .mix),
        ("Plug-in: EQ3 7-Band", .plugIn),
        ("Plug-in: Preferences", .plugIn),
        ("Plug-in: Audio Suite: X", .plugIn),
        ("Audio Suite: Gain", .audioSuite),
        ("Audio Suite: Dashboard", .audioSuite),
        ("Fade In", .fade(.fadeIn)),
        ("Fade Out", .fade(.fadeOut)),
        ("Crossfade", .fade(.crossfade)),
        ("Batch Fades", .fade(.batchFades)),
        ("fade in", .fade(.fadeIn)),
        ("Fade In Options", .other),
        ("I/O Setup", .tabbedSetup),
        ("Peripherals", .tabbedSetup),
        ("Pro Tools Preferences", .tabbedSetup),
        ("Dashboard", .tabbedSetup),
        ("Session Notes", .other),
        ("Missing AAX Plugins", .other),
        ("", .other),
    ]

    @Test func classifiesTitles() {
        for (title, kind) in Self.titles {
            #expect(ProToolsWindowKind(title: title) == kind, "\(title)")
        }
    }

    @Test func contextHasKindOnlyForProToolsWindows() {
        #expect(FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Fade In").proToolsWindowKind == .fade(.fadeIn))
        #expect(FrontContext(bundleID: ProToolsApp.bundleID).proToolsWindowKind == nil)
        #expect(FrontContext(bundleID: "com.apple.finder", windowTitle: "Mix: I Trust").proToolsWindowKind == nil)
    }

    /// The kinds agree with the window conditions of today's groups, so moving bindings from groups to kinds changes no routing, except for the titles where two groups overlap today: there the kind decides, and the other group is listed.
    @Test func agreesWithGroupConditions() throws {
        let overlaps: [String: MacroGroupID] = ["Mix: Audio Suite: odd session name": .audioSuite, "Plug-in: Audio Suite: X": .audioSuite]
        let groupOfKind: [String: MacroGroupID] = [
            "Mix": .inspector, "Edit": .inspector, "Plug-in": .plugin, "AudioSuite": .audioSuite,
            "Fade In": .fadeIn, "Fade Out": .fadeOut, "Crossfade": .crossfade, "Batch Fades": .batchFades, "setup tabs": .selectedTab,
        ]
        let windowGroups = FloMacros.groups.filter { $0.title != .any }
        for (title, _) in Self.titles {
            let kind = ProToolsWindowKind(title: title)
            let matching = windowGroups.filter { $0.title.matches(title) }.map(\.id)
            let expected = (groupOfKind[kind.description].map { [$0] } ?? []) + (overlaps[title].map { [$0] } ?? [])
            #expect(matching == expected, "\(title) is \(kind)")
        }
    }
}
