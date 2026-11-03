import ApplicationServices
import FloSystem

/// What the user hears when a macro fails: the one table for failure wording. The Keyboard Maestro version showed a notification instead.
public enum SpokenError {
    /// Nil means say nothing, as for cancellation.
    public static func text(for error: Error) -> String? {
        switch error {
        case is CancellationError:
            return nil
        case FloError.notFound(let what):
            return "Could not find \(what)."
        case FloError.cycle:
            return "Flo Tools macro error."
        case FloError.voiceOver:
            // Speaking this usually fails too; it is still worth trying, because only one call may have timed out.
            return "VoiceOver did not respond."
        case FloError.accessibility(_, AXError.cannotComplete.rawValue):
            return "Pro Tools did not respond."
        case FloError.accessibility(_, AXError.apiDisabled.rawValue):
            return "Flo Tools needs Accessibility access."
        default:
            return "Flo Tools error."
        }
    }
}
