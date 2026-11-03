import AVFoundation

/// Speech through the system voice, for the one case where VoiceOver cannot speak for Flo Tools: telling the user that Flo Tools cannot control VoiceOver. Everything else speaks through `VoiceOver`.
@MainActor
public enum SystemSpeech {
    /// Kept for the app's lifetime: a synthesizer that is released stops speaking.
    private static let synthesizer = AVSpeechSynthesizer()

    public static func say(_ text: String) {
        Log.info(.voiceover, "system voice says \"\(text)\"")
        synthesizer.speak(AVSpeechUtterance(string: text))
    }
}
