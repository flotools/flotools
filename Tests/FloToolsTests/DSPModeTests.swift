import Testing
import FloSystem
@testable import FloProTools
@testable import FloFeatures

@Suite struct DSPModeTests {
    @Test func readsTheObservedButtonLabels() throws {
        #expect(try DSPMode(reading: "Native Mode") == .native)
        #expect(try DSPMode(reading: "DSP Mode enabled") == .enabled)
        #expect(try DSPMode(reading: "DSP Mode is automatically enabled because one or more tracks routed to \"Reverb\" are in DSP mode") == .automaticallyEnabled)
        #expect(try DSPMode(reading: "DSP Mode is automatically enabled because one or more tracks routed to \"DSP Mode enabled\" are in DSP mode") == .automaticallyEnabled)
    }

    @Test func unknownLabelsAreErrorsRatherThanNativeOrDSP() {
        for label in ["", "Selected", "Insert selector A - DSP plugin active", "DSP Mode unavailable"] {
            #expect(throws: FloError.unexpectedValue("the DSP mode: \(label)")) {
                try DSPMode(reading: label)
            }
        }
    }

    @Test func readOnlyDSPQueriesCannotChangeTracks() async {
        // These queries must fail before attempting any Accessibility lookup.
        let app = ProToolsApp(pid: -1)
        for mode in [DSPMode.automaticallyEnabled, .native] {
            await #expect(throws: FloError.couldNot("change a read-only DSP list")) {
                try await app.change(["Reverb - Aux Track "], outOf: .dsp(mode))
            }
        }
    }

    @Test func chooserSeparatesExplicitAndAutomaticDSP() throws {
        let explicit = try #require(TrackLists.listings.first { $0.name == "List DSP Tracks" })
        let automatic = try #require(TrackLists.listings.first { $0.name == "List Auto-Enabled DSP Tracks" })
        #expect(explicit.source == .dsp(.enabled))
        #expect(automatic.source == .dsp(.automaticallyEnabled))
        #expect(explicit.source != automatic.source)
        #expect(explicit.action == .change("Toggle DSP"))
        #expect(explicit.prompt == "Choose tracks to toggle DSP mode.")
        #expect(explicit.okTitle == "Toggle DSP")
        #expect(automatic.action == .readOnly)
        #expect(automatic.prompt == "DSP is automatically enabled on these tracks because of routing.")
        #expect(automatic.okTitle == "Close")
        guard case .says(let explicitNone) = explicit.none,
              case .says(let automaticNone) = automatic.none else {
            Issue.record("Both DSP lists need their own empty-list messages")
            return
        }
        #expect(explicitNone == "No shown tracks have explicitly enabled DSP.")
        #expect(automaticNone == "No shown tracks have automatically enabled DSP.")
    }
}
