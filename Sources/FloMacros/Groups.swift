import FloEngine
import FloProTools
import FloSystem

extension MacroGroupID {
    static let floTools: MacroGroupID = "floTools"
    static let inspector: MacroGroupID = "inspector"
    static let global: MacroGroupID = "global"
    static let selectedTab: MacroGroupID = "selectedTab"
    static let plugin: MacroGroupID = "plugin"
    static let audioSuite: MacroGroupID = "audioSuite"
    static let fadeOut: MacroGroupID = "fadeOut"
    static let fadeIn: MacroGroupID = "fadeIn"
    static let batchFades: MacroGroupID = "batchFades"
    static let crossfade: MacroGroupID = "crossfade"
}

extension FloMacros {
    static let proTools = ProToolsApp.bundleID
    static let selectedTabTitle = "^(?!(Mix:|Edit:|Plug-in:|.*Audio Suite:)).*(I/O Setup|Peripherals|Preferences|Dashboard)"

    /// The macro groups, with the app and window conditions of the Keyboard Maestro groups they came from.
    public static let groups: [MacroGroup] = [
        MacroGroup(.floTools, name: "Flo Tools", bundleIDs: [proTools]),
        MacroGroup(.inspector, name: "Flo Tools Inspector", bundleIDs: [proTools], title: .matches("^(Mix|Edit):")),
        MacroGroup(.global, name: "Flo Tools Global", bundleIDs: []),
        // KM matched these words anywhere, so a session or plug-in named "Dashboard" made Cmd+1 to 9 ambiguous between Selected Tab and the Inspector or Plugin group. The other window groups' titles are left out.
        MacroGroup(.selectedTab, name: "Flo Tools Selected Tab", bundleIDs: [proTools], title: .matches(selectedTabTitle)),
        MacroGroup(.plugin, name: "Flo Tools Plugin", bundleIDs: [proTools], title: .matches("^Plug-in:")),
        MacroGroup(.audioSuite, name: "Flo Tools Audio Suite", bundleIDs: [proTools], title: .contains("Audio Suite:")),
        MacroGroup(.fadeOut, name: "Flo Tools Fade Out", bundleIDs: [proTools], title: .is("Fade Out")),
        MacroGroup(.fadeIn, name: "Flo Tools Fade In", bundleIDs: [proTools], title: .is("Fade In")),
        MacroGroup(.batchFades, name: "Flo Tools Batch Fades", bundleIDs: [proTools], title: .is("Batch Fades")),
        MacroGroup(.crossfade, name: "Flo Tools Crossfade", bundleIDs: [proTools], title: .is("Crossfade")),
    ]
}
