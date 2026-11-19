import FloSystem

/// New Tracks exposes each row's controls as immediate children in row order.
@AccessibilityActor
public struct NewTracksDialog {
    public enum Setting: String, Sendable {
        case format = "Track format"
        case type = "Track type"
        case timebase = "Track Timebase"
    }

    private let element: AXElement

    init(_ element: AXElement) { self.element = element }

    /// Read every row because the native shortcut chooses its row independently of the VoiceOver cursor.
    public func values(for setting: Setting) throws -> [String] {
        let controls = try element.children(role: "AXPopUpButton").filter {
            try $0.string("AXDescription") == setting.rawValue
        }
        _ = try element.required("the New Tracks \(setting.rawValue) pop-up") { _ in controls.first }
        return try controls.map { try $0.value.required("the New Tracks \(setting.rawValue) value") }
    }

    public func rowCount() throws -> Int { try values(for: .type).count }
}
