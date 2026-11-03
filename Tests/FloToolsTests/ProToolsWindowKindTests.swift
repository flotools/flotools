import Testing
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
        ("Keyboard Shortcuts", .keyboardShortcuts),
        ("keyboard shortcuts", .keyboardShortcuts),
        ("Keyboard Shortcuts Help", .other),
        ("Session Notes", .other),
        ("Missing AAX Plugins", .other),
        ("", .other),
    ]

    @Test func classifiesTitles() {
        for (title, kind) in Self.titles {
            #expect(ProToolsWindowKind(title: title) == kind, "\(title)")
        }
    }

    @Test func onlyMixAndEditAreTrackWindows() {
        #expect(ProToolsWindowKind(title: "Mix: I Trust").isTrackWindow)
        #expect(ProToolsWindowKind(title: "edit: I Trust").isTrackWindow)
        #expect(!ProToolsWindowKind(title: "Plug-in: Mix: Bus").isTrackWindow)
        #expect(!ProToolsWindowKind(title: "Session Notes: Edit: draft").isTrackWindow)
        #expect(!ProToolsWindowKind(title: "Audio Suite: Gain").isTrackWindow)
    }

    @Test func contextHasKindOnlyForProToolsWindows() {
        #expect(FrontContext(bundleID: ProToolsApp.bundleID, windowTitle: "Fade In").proToolsWindowKind == .fade(.fadeIn))
        #expect(FrontContext(bundleID: ProToolsApp.bundleID).proToolsWindowKind == nil)
        #expect(FrontContext(bundleID: "com.apple.finder", windowTitle: "Mix: I Trust").proToolsWindowKind == nil)
    }
}
