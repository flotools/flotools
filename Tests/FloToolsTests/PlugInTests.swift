import CoreGraphics
import Foundation
import Testing
@testable import FloFeatures
@testable import FloProTools
@testable import FloSystem

@Suite struct PlugInViewTests {
    /// The shipped Dyn3 view, as the KM installer put it in the Plug-In Views folder.
    static let dyn3 = """
    {"view":"Default", "click":[-1,-1], "parameters":[
    [
    ["Knee Width",200,290],
    ["Ratio",200,356]
    ],
    [
    ["Gain",450,290]
    ]
    ]}
    """

    @Test func readsTheKMFormat() throws {
        let view = try PlugInView(json: Data(Self.dyn3.utf8))
        #expect(view.name == "Default")
        #expect(view.click == nil)
        #expect(view.rows.map { $0.map(\.name) } == [["Knee Width", "Ratio"], ["Gain"]])
        #expect(view.rows[0][1].point == CGPoint(x: 200, y: 356))
    }

    @Test func readsAClickPoint() throws {
        let view = try PlugInView(json: Data(#"{"view":"View 1", "click":[12,30], "parameters":[]}"#.utf8))
        #expect(view.click == CGPoint(x: 12, y: 30))
    }

    @Test func rejectsABadFile() {
        #expect(throws: FloError.self) { try PlugInView(json: Data("not json".utf8)) }
        #expect(throws: FloError.self) { try PlugInView(json: Data(#"{"view":"V", "click":[-1,-1], "parameters":[[["Gain",1]]]}"#.utf8)) }
        // A position far off any screen, such as a typing slip, is rejected rather than clicked or trapping a later Int conversion.
        #expect(throws: FloError.self) { try PlugInView(json: Data(#"{"view":"V", "click":[-1,-1], "parameters":[[["Gain",1e300,2]]]}"#.utf8)) }
        #expect(throws: FloError.self) { try PlugInView(json: Data(#"{"view":"V", "click":[99999,0], "parameters":[]}"#.utf8)) }
    }

    @Test func shippedViewFilesAreReadable() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "../../reference/Plug-In Views")
        for name in ["Dyn3 Compressor Limiter", "EQ3 7-Band"] {
            let view = try #require(try PlugInView.load(plugIn: name, view: nil, from: folder))
            #expect(!view.rows.isEmpty)
        }
        #expect(try PlugInView.load(plugIn: "EQ3 7-Band", view: 1, from: folder)?.name == "View 1")
        #expect(try PlugInView.load(plugIn: "No Such Plug-in", view: nil, from: folder) == nil)
    }

    @Test func fileNames() {
        #expect(PlugInView.fileName(plugIn: "EQ3 7-Band", view: nil) == "EQ3 7-Band.txt")
        #expect(PlugInView.fileName(plugIn: "EQ3 7-Band", view: 3) == "EQ3 7-Band-3.txt")
        #expect(PlugInWindow.plugInName(fromTitle: "Plug-in: Pro-Q 3/Stereo", kind: .plugIn) == "Pro-Q 3/Stereo")
        #expect(PlugInView.fileName(plugIn: "Pro-Q 3/Stereo", view: nil) == "Pro-Q 3 Stereo.txt")
        #expect(PlugInView.fileName(plugIn: "a/b/c", view: 2) == "a b c-2.txt")
        #expect(PlugInView.template(plugIn: "a/b", parameters: []).hasPrefix("a b\n"))
    }

    /// The JXA clamped the row to the view and the column to the row, starting from -1, -1.
    @Test func movesLikeTheJXA() throws {
        let view = try PlugInView(json: Data(Self.dyn3.utf8))
        typealias P = PlugInView.Position
        #expect(view.position(after: nil, rows: 1, columns: 0) == P(row: 0, column: 0))
        #expect(view.position(after: nil, rows: -1, columns: 0) == P(row: 0, column: 0))
        #expect(view.position(after: nil, rows: 0, columns: 1) == P(row: 0, column: 0))
        #expect(view.position(after: P(row: 0, column: 0), rows: 0, columns: 1) == P(row: 0, column: 1))
        #expect(view.position(after: P(row: 0, column: 1), rows: 0, columns: 1) == P(row: 0, column: 1))
        // Down into a shorter row keeps the column inside it.
        #expect(view.position(after: P(row: 0, column: 1), rows: 1, columns: 0) == P(row: 1, column: 0))
        #expect(view.position(after: P(row: 1, column: 0), rows: 1, columns: 0) == P(row: 1, column: 0))
        let empty = try PlugInView(json: Data(#"{"view":"V", "click":[-1,-1], "parameters":[[]]}"#.utf8))
        #expect(empty.position(after: nil, rows: 1, columns: 0) == nil)
    }

    @Test func cursorStartsOverOnLoad() async throws {
        let cursor = PlugInViewCursor()
        await #expect(throws: FloError.self) { try await cursor.move(rows: 1, columns: 0) }
        await cursor.load(try PlugInView(json: Data(Self.dyn3.utf8)))
        #expect(try await cursor.move(rows: 0, columns: 1).name == "Knee Width")
        #expect(try await cursor.move(rows: 0, columns: 1).name == "Ratio")
        await cursor.load(try PlugInView(json: Data(Self.dyn3.utf8)))
        #expect(try await cursor.move(rows: 1, columns: 0).name == "Knee Width")
    }

    @Test func templateMatchesTheJXA() throws {
        let text = PlugInView.template(plugIn: "Dyn3 Compressor Limiter", parameters: ["Knee Width", "Ratio"])
        #expect(text == "Dyn3 Compressor Limiter\n{\"view\":\"Default\", \"click\":[-1,-1], \"parameters\":[\n[\n[\"Knee Width\",0,0],\n[\"Ratio\",0,0]\n]\n]}")
        // Everything after the first line is a readable view file.
        let file = text.split(separator: "\n", maxSplits: 1)[1]
        #expect(try PlugInView(json: Data(file.utf8)).rows[0].count == 2)
        let odd = [#"Say "hi""#, "Tab\there", #"Back\slash"#, "In/Out"]
        let quoted = PlugInView.template(plugIn: "X", parameters: odd)
        #expect(try PlugInView(json: Data(quoted.split(separator: "\n", maxSplits: 1)[1].utf8)).rows[0].map(\.name) == odd)
    }

    @Test func spokenText() {
        #expect(PlugIns.bypassText(true) == "On")
        #expect(PlugIns.bypassText(false) == "Off")
        #expect(PlugIns.changeText(PlugInWindow.Parameter(name: "Gain", value: "3.0 dB")) == "3.0 dB: Gain")
    }
}
