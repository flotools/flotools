/// A yes-or-no state of a track that the track list commands report and change, read from one of the strip's toggle buttons. Each flag also decides which tracks take part: the JXA left out tracks that cannot have the state (a master track cannot be armed) and tracks whose button shows something else (solo safe, inactive).
public enum TrackFlag: Sendable, CaseIterable {
    case soloed, muted, recordArmed, inputMonitored, soloSafe, recordSafe

    /// The button that shows the flag.
    public var toggle: TrackStrip.Toggle {
        switch self {
        case .soloed, .soloSafe: .solo
        case .muted: .mute
        case .recordArmed, .recordSafe: .recordEnable
        case .inputMonitored: .inputMonitor
        }
    }

    /// Whether a track whose flag now reads `state` (from `state(of:track:buttonState:)`) ends as asked after a press. Turning the flag on needs the flag. Turning it off also counts a track that stopped taking part, for example one that became inactive, as the reset-all check did before.
    public static func isSettled(_ state: Bool?, on: Bool) -> Bool {
        on ? state == true : state != true
    }

    /// Whether the track has the flag, or nil when it does not take part. `buttonState` is `TrackStrip.state(of:)` of `toggle`: the button's value, empty when off, or the name of a named input monitoring button.
    /// The rules are the JXA filters: solo and mute leave out master tracks; mute leaves out tracks muted only by another track's solo; arming leaves out master, aux and folder tracks; input monitoring counts audio tracks only. Inactive tracks never take part.
    public static func state(of flag: TrackFlag, track kind: TrackKind, buttonState: String) -> Bool? {
        let state = buttonState.lowercased()
        guard !state.contains("inactive") else { return nil }
        let isSafe = state.contains("safe")
        switch flag {
        case .soloed:
            guard kind != .master, !isSafe else { return nil }
            return !state.isEmpty
        case .soloSafe:
            guard kind != .master else { return nil }
            return isSafe
        case .muted:
            guard kind != .master, !state.contains("solo") else { return nil }
            return !state.isEmpty
        case .recordArmed:
            guard canArm(kind), !isSafe else { return nil }
            return !state.isEmpty
        case .recordSafe:
            guard canArm(kind) else { return nil }
            return isSafe
        case .inputMonitored:
            guard kind == .audio else { return nil }
            // A named button says "Input monitoring enabled" or "Input monitoring disabled"; the older "TrackInput Monitor" button has the value "on".
            return state.contains("input monitoring enabled") || state == "on"
        }
    }

    private static func canArm(_ kind: TrackKind) -> Bool {
        ![.master, .folder, .aux].contains(kind)
    }
}
