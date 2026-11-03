import AppKit

/// System sounds used as feedback, like `kme.playSound(Path("/System/Library/Sounds/Tink.aiff"))`.
@MainActor
public enum Sound {
    public static func play(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }
}
