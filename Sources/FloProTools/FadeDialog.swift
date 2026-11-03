import FloSystem

/// One of Pro Tools' fade dialogs (Fade In, Fade Out, Crossfade, Batch Fades). Each setting is a group of radio buttons, and a shape group also has a pop-up button with the group's name that picks the curve.
@AccessibilityActor
public struct FadeDialog {
    /// The dialog titles, by which `ProToolsWindowKind` recognizes them.
    public enum Kind: String, Sendable, CaseIterable {
        case fadeIn = "Fade In"
        case fadeOut = "Fade Out"
        case crossfade = "Crossfade"
        case batchFades = "Batch Fades"
    }

    /// A setting in the dialog: the group's title, and which group of that title, counted from 0, because Batch Fades has two groups called "Slope" (fade in, then fade out).
    public struct Section: Sendable, Equatable {
        public let title: String
        public let occurrence: Int

        public init(_ title: String, occurrence: Int = 0) {
            self.title = title
            self.occurrence = occurrence
        }

        // The groups the fade commands read, named once so a Pro Tools rename is one change. Fade In and Fade Out call their link group "Slope" too, which the JXA called "Link Out / In" (checked live 2026-11-03).
        public static let inShape = Section("In Shape")
        public static let outShape = Section("Out Shape")
        public static let slope = Section("Slope")
        /// Batch Fades' second "Slope" group, the fade out slope.
        public static let batchOutSlope = Section("Slope", occurrence: 1)
        public static let crossfadeLink = Section("<<- Link ->>")
        public static let fadeInShape = Section("Fade In Shape")
        public static let fadeOutShape = Section("Fade Out Shape")
    }

    private let element: AXElement

    init(_ element: AXElement) { self.element = element }

    /// The name of the selected radio button, for example "S-Curve". Empty when none is selected.
    public func selectedOption(in section: Section) throws -> String {
        let options = try group(section).children(role: "AXRadioButton")
        return try options.first { try $0.value == "1" }?.name ?? ""
    }

    /// The curve the shape pop-up button shows, for example "-3 dB".
    public func curve(in section: Section) throws -> String {
        let popUp = try group(section).required("the \(section.title) curve") { try $0.child(role: "AXPopUpButton", name: section.title) }
        return try popUp.value ?? ""
    }

    private func group(_ section: Section) throws -> AXElement {
        try element.required("the \(section.title) settings") { dialog in
            let matches = try dialog.groups.filter { try $0.name == section.title }
            return section.occurrence < matches.count ? matches[section.occurrence] : nil
        }
    }
}
