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
        default:
            return "Flo Tools error."
        }
    }
}
