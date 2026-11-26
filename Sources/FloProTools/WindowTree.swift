import FloSystem

/// Pro Tools' focused window as a full attribute tree, added at the end of the diagnostic log when it is turned off. Failures are logged where they happen; this shows the rest of the window as it was.
extension ProToolsApp {
    /// The tree of the focused window, without track strips and with at most three rows of each table. `FloError.notFound` when Pro Tools has no focused window.
    @AccessibilityActor
    public func focusedWindowTree(budget: Duration = .seconds(10)) throws -> String {
        try frontWindow("the focused window").attributeDump(depth: .max, maxCharacters: .max, budget: budget, keep: WindowTree.kept(parent:children:))
    }
}

/// Which children of a Pro Tools element the window tree dumps. A whole Mix window of the Intro Demo was 3,167 elements and 2.5 MB, nearly all of it track strips and table rows that repeat one layout (measured 2026-11-26).
enum WindowTree {
    /// Track strips: "CHdr" in the Mix window, "LHdr" in the Edit window (seen 2026-11-26). A failed lookup in a strip already logs that strip.
    static let trackStripIdentifiers: Set<String> = ["CHdr", "LHdr"]

    /// Everything except track strips and rows, plus the first row, the last row and the first selected row. A column's rows are all left out: they are the table's rows again, each with all its cells (seen 2026-11-26: the one-row Markers table came out seven times).
    static func kept(parent: AXElement.DumpChild, children: [AXElement.DumpChild]) -> Set<Int> {
        let rows = children.indices.filter { children[$0].role == "AXRow" }
        let sampleRows = parent.role == "AXColumn" ? [] : [rows.first, rows.last, rows.first { children[$0].isSelected }].compactMap { $0 }
        let others = children.indices.filter { index in
            children[index].role != "AXRow" && !trackStripIdentifiers.contains(children[index].identifier ?? "")
        }
        return Set(others).union(sampleRows)
    }
}
