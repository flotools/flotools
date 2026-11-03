/// What commands remember between runs about the current Pro Tools session: the clip marked for drag, the loaded plug-in view and its parameter, the deepest gain reduction and the MIDI event column. These replace the KM variables that Cleanup Variables deleted (point1, FTPluginControlParameters, FTPluginControlIndex, FTGRMax, FTEventIndex).
///
/// The app creates one and hands it to the commands and to `Lifecycle`, which resets it when Pro Tools quits. A session closed without quitting Pro Tools is not seen here; the clip mark checks its own Edit window for that. Each part is an actor, or isolated to one, so this holder is immutable and can be shared freely.
public final class SessionState: Sendable {
    let clipMark = ClipDragMark()
    let plugInView = PlugInViewCursor()
    let gainReduction = GainReductionPeak()
    let eventColumn = EventColumnCursor()

    public init() {}

    func reset() async {
        await clipMark.clear()
        await plugInView.clear()
        await gainReduction.reset()
        await eventColumn.reset()
    }
}
