import AppKit

/// Feedback sounds, shipped in the app's `Contents/Resources` (copied from `Resources/Sounds` by `scripts/build-app.sh`). The KM version played system sounds such as `/System/Library/Sounds/Tink.aiff`; bundling them keeps Flo Tools independent of what macOS ships.
@MainActor
public enum Sound: String {
    /// An action finished, for example after a double press. Was Tink.
    case done = "Done"
    /// A long job is still working, for example during Unsolo All. Was Pop.
    case progress = "Progress"

    public func play() {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "aiff"), let sound = NSSound(contentsOf: url, byReference: true) else {
            Log.warning(.app, "sound \(rawValue).aiff is missing from the app bundle")
            return
        }
        sound.play()
    }
}
