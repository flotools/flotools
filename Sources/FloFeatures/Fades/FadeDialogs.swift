import FloEngine
import FloProTools
import FloSystem

/// The Fade In, Fade Out, Crossfade and Batch Fades groups. Every command passes its key to the dialog, where Pro Tools changes a setting, then speaks the new setting.
enum FadeDialogs {
    @MainActor
    static var commands: [Command] { settings.map(command) }

    /// Spoken text is the JXA's, with two changes on purpose: "Crossffade" is spelled right, and Out Slope reads the second "Slope" group, where the JXA read the first (the fade in slope).
    static let settings: [FadeSetting] = [
        // Flo Tools Fade In
        FadeSetting("fadeIn.nextFadeInShapeCurve", "Next Fade In Shape Curve", .fadeIn, key: "Opt+Right", .curve, .init("In Shape"), suffix: ", Fade In"),
        FadeSetting("fadeIn.nextFadeInShapeParameter", "Next Fade In Shape Parameter", .fadeIn, key: "Down", .option, .init("In Shape"), suffix: ", Fade In."),
        // Opt+Cmd+Down and Up step the Fade In and Fade Out dialogs' "Slope" group, which the JXA called "Link Out / In" (checked live 2026-11-03).
        FadeSetting("fadeIn.nextLinkOutIn", "Next Link Out/In", .fadeIn, key: "Opt+Cmd+Down", .option, .init("Slope"), suffix: ", Link Out/In."),
        FadeSetting("fadeIn.previousFadeInShapeCurve", "Previous Fade In Shape Curve", .fadeIn, key: "Opt+Left", .curve, .init("In Shape"), suffix: ", Fade In."),
        FadeSetting("fadeIn.previousFadeInShapeParameter", "Previous Fade In Shape Parameter", .fadeIn, key: "Up", .option, .init("In Shape"), suffix: ", In Shape ."),
        FadeSetting("fadeIn.previousLinkOutIn", "Previous Link Out/In", .fadeIn, key: "Opt+Cmd+Up", .option, .init("Slope"), suffix: ", Link Out/In."),
        // Flo Tools Fade Out
        FadeSetting("fadeOut.nextFadeOutShapeCurve", "Next Fade Out Shape Curve", .fadeOut, key: "Cmd+Right", .curve, .init("Out Shape"), suffix: ", Fade Out."),
        FadeSetting("fadeOut.nextFadeOutShapeParameter", "Next Fade Out Shape Parameter", .fadeOut, key: "Down", .option, .init("Out Shape"), suffix: ", Out Shape ."),
        FadeSetting("fadeOut.nextLinkOutIn", "Next Link Out/In", .fadeOut, key: "Opt+Cmd+Down", .option, .init("Slope"), suffix: ", Link Out/In."),
        FadeSetting("fadeOut.previousFadeOutShapeCurve", "Previous Fade Out Shape Curve", .fadeOut, key: "Cmd+Left", .curve, .init("Out Shape"), suffix: ", Fade Out."),
        FadeSetting("fadeOut.previousFadeOutShapeParameter", "Previous Fade Out Shape Parameter", .fadeOut, key: "Up", .option, .init("Out Shape"), suffix: ", Out Shape ."),
        FadeSetting("fadeOut.previousLinkOutIn", "Previous Link Out/In", .fadeOut, key: "Opt+Cmd+Up", .option, .init("Slope"), suffix: ", Link Out/In."),
        // Flo Tools Crossfade. Down and Up step the slope options, which the JXA read from a group named "Link Out / In"; Pro Tools 26.10 names it "Slope" (checked live 2026-11-03). The spoken suffix stays the JXA's.
        FadeSetting("crossfade.nextCrossfadeInShapeCurve", "Next Crossfade In Shape Curve", .crossfade, key: "Opt+Right", .curve, .init("In Shape"), suffix: ", Crossfade, In."),
        FadeSetting("crossfade.nextCrossfadeInShapeParameter", "Next Crossfade In Shape Parameter", .crossfade, key: "Opt+Down", .option, .init("In Shape"), suffix: ", Crossfade In Shape."),
        FadeSetting("crossfade.nextCrossfadeOutShapeCurve", "Next Crossfade Out Shape Curve", .crossfade, key: "Cmd+Right", .curve, .init("Out Shape"), suffix: ", Crossfade, Out."),
        FadeSetting("crossfade.nextLinkOutIn", "Next Link Out / In", .crossfade, key: "Down", .option, .init("Slope"), suffix: ", Link Out/In."),
        FadeSetting("crossfade.nextCrossfadeOutShapeParameter", "Next crossfade Out Shape Parameter", .crossfade, key: "Cmd+Down", .option, .init("Out Shape"), suffix: ", Crossfade Out Shape."),
        FadeSetting("crossfade.previousCrossfadeInShapeCurve", "Previous Crossfade In Shape Curve", .crossfade, key: "Opt+Left", .curve, .init("In Shape"), suffix: ", Crossfade, In."),
        FadeSetting("crossfade.previousCrossfadeInShapeParameter", "Previous Crossfade In Shape Parameter", .crossfade, key: "Opt+Up", .option, .init("In Shape"), suffix: ", Crossfade In Shape."),
        FadeSetting("crossfade.previousCrossfadeOutShapeCurve", "Previous Crossfade Out Shape Curve", .crossfade, key: "Cmd+Left", .curve, .init("Out Shape"), suffix: ", Crossfade, Out."),
        FadeSetting("crossfade.previousCrossfadeOutShapeParameter", "Previous Crossfade Out Shape Parameter", .crossfade, key: "Cmd+Up", .option, .init("Out Shape"), suffix: ", Crossfade Out Shape."),
        FadeSetting("crossfade.previousLinkOutIn", "Previous Link Out / In", .crossfade, key: "Up", .option, .init("Slope"), suffix: ", Link Out/In."),
        // Flo Tools Batch Fades
        FadeSetting("batchFades.nextCrossfadeInShapeCurve", "Next Crossfade In Shape Curve", .batchFades, key: "Opt+Right", .curve, .init("In Shape"), suffix: ", Crossfade In Shape Curve."),
        FadeSetting("batchFades.nextCrossfadeInShapeParameter", "Next Crossfade In Shape Parameter", .batchFades, key: "Opt+Down", .option, .init("In Shape"), suffix: ", Crossfade In Shape ."),
        FadeSetting("batchFades.nextCrossfadeLink", "Next Crossfade Link", .batchFades, key: "Opt+Cmd+Down", .option, .init("<<- Link ->>"), suffix: ", Crossfade Link."),
        FadeSetting("batchFades.nextCrossfadeOutShapeCurve", "Next Crossfade Out Shape Curve", .batchFades, key: "Opt+Shift+Right", .curve, .init("Out Shape"), suffix: ", Crossfade Out Shape Curve."),
        FadeSetting("batchFades.nextCrossfadeOutShapeParameter", "Next Crossfade Out Shape Parameter", .batchFades, key: "Opt+Shift+Down", .option, .init("Out Shape"), suffix: ", Crossfade Out Shape."),
        FadeSetting("batchFades.nextFadeInShapeCurve", "Next Fade In Shape Curve", .batchFades, key: "Shift+Right", .curve, .init("Fade In Shape"), suffix: ", Fade In Shape Curve."),
        FadeSetting("batchFades.nextFadeInShapeParameter", "Next Fade In Shape Parameter", .batchFades, key: "Shift+Down", .option, .init("Fade In Shape"), suffix: ", Fade In Shape ."),
        FadeSetting("batchFades.nextFadeOutShapeCurve", "Next Fade Out Shape Curve", .batchFades, key: "Cmd+Right", .curve, .init("Fade Out Shape"), suffix: ", Fade Out Shape Curve."),
        FadeSetting("batchFades.nextFadeOutShapeParameter", "Next Fade Out Shape Parameter", .batchFades, key: "Cmd+Down", .option, .init("Fade Out Shape"), suffix: ", Fade Out Shape.."),
        FadeSetting("batchFades.nextInSlope", "Next In Slope", .batchFades, key: "Shift+Cmd+Down", .option, .init("Slope"), suffix: ", In Slope ."),
        FadeSetting("batchFades.nextOutSlope", "Next Out Slope", .batchFades, key: "Ctrl+Cmd+Down", .option, .init("Slope", occurrence: 1), suffix: ", Out Slope ."),
        FadeSetting("batchFades.previousCrossfadeInShapeCurve", "Previous Crossfade In Shape Curve", .batchFades, key: "Opt+Left", .curve, .init("In Shape"), suffix: ", Crossfade In Shape Curve."),
        FadeSetting("batchFades.previousCrossfadeInShapeParameter", "Previous Crossfade In Shape Parameter", .batchFades, key: "Opt+Up", .option, .init("In Shape"), suffix: ", Crossfade In Shape ."),
        FadeSetting("batchFades.previousCrossfadeLink", "Previous Crossfade Link", .batchFades, key: "Opt+Cmd+Up", .option, .init("<<- Link ->>"), suffix: ", Crossfade Link."),
        FadeSetting("batchFades.previousCrossfadeOutShapeCurve", "Previous Crossfade Out Shape Curve", .batchFades, key: "Opt+Shift+Left", .curve, .init("Out Shape"), suffix: ", Crossfade Out Shape Curve."),
        FadeSetting("batchFades.previousCrossfadeOutShapeParameter", "Previous Crossfade Out Shape Parameter", .batchFades, key: "Opt+Shift+Up", .option, .init("Out Shape"), suffix: ", Crossfade Out Shape ."),
        FadeSetting("batchFades.previousFadeInShapeCurve", "Previous Fade In Shape Curve", .batchFades, key: "Shift+Left", .curve, .init("Fade In Shape"), suffix: ", Fade In Shape Curve."),
        FadeSetting("batchFades.previousFadeInShapeParameter", "Previous Fade In Shape Parameter", .batchFades, key: "Shift+Up", .option, .init("Fade In Shape"), suffix: ", Fade In Shape ."),
        FadeSetting("batchFades.previousFadeOutShapeCurve", "Previous Fade Out Shape Curve", .batchFades, key: "Cmd+Left", .curve, .init("Fade Out Shape"), suffix: ", Fade Out Shape Curve."),
        FadeSetting("batchFades.previousFadeOutShapeParameter", "Previous Fade Out Shape Parameter", .batchFades, key: "Cmd+Up", .option, .init("Fade Out Shape"), suffix: ", Fade Out Shape ."),
        FadeSetting("batchFades.previousInSlope", "Previous In Slope", .batchFades, key: "Shift+Cmd+Up", .option, .init("Slope"), suffix: ", In Slope ."),
        FadeSetting("batchFades.previousOutSlope", "Previous Out Slope", .batchFades, key: "Ctrl+Cmd+Up", .option, .init("Slope", occurrence: 1), suffix: ", Out Slope ."),
    ]

    /// What a command reads after its key: the shape curve pop-up button, or the selected radio button of the section.
    enum Reading: Sendable { case curve, option }

    @MainActor
    static func command(_ setting: FadeSetting) -> Command {
        let combo = KeyCombo(literal: setting.key)
        return Command(setting.id, setting.name, summary: setting.summary, scope: .windows([.fade(setting.dialog)]), triggers: [.key(setting.key)]) { _ in
            let proTools = try ProToolsApp.running()
            let dialog = try await proTools.fadeDialog(setting.dialog)
            let before = try await read(setting.reading, setting.section, in: dialog)
            try await proTools.keystroke(combo)
            // Radio buttons stop at the first and last choice; there the key changes nothing and the unchanged setting is spoken.
            let now = try await ProToolsUpdate.reading(changedFrom: before) { try read(setting.reading, setting.section, in: dialog) }
            try await VoiceOver.say(now + setting.suffix)
        }
    }

    @AccessibilityActor
    static func read(_ reading: Reading, _ section: FadeDialog.Section, in dialog: FadeDialog) throws -> String {
        switch reading {
        case .curve: try dialog.curve(in: section)
        case .option: try dialog.selectedOption(in: section)
        }
    }

}

/// One fade dialog command: its key changes `section` in `dialog`, and it speaks the new value followed by `suffix`.
struct FadeSetting: Sendable {
    let id: CommandID
    let name: String
    let dialog: FadeDialog.Kind
    let key: String
    let reading: FadeDialogs.Reading
    let section: FadeDialog.Section
    let suffix: String

    init(_ id: CommandID, _ name: String, _ dialog: FadeDialog.Kind, key: String, _ reading: FadeDialogs.Reading, _ section: FadeDialog.Section, suffix: String) {
        self.id = id
        self.name = name
        self.dialog = dialog
        self.key = key
        self.reading = reading
        self.section = section
        self.suffix = suffix
    }

    /// For `COMMANDS.md`, for example "Passes the key to the dialog, which selects the next curve in the "In Shape" section, and speaks it."
    var summary: String {
        let direction = name.hasPrefix("Next") ? "next" : "previous"
        let thing = reading == .curve ? "curve" : "option"
        let place = (section.occurrence == 0 ? "the" : "the second") + " \"\(section.title)\" section"
        return "Passes the key to the dialog, which selects the \(direction) \(thing) in \(place), and speaks it."
    }
}
