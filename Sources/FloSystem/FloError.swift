/// The one error model. Core code throws these so the engine can log why a macro stopped and tell the user (`SpokenError` in `FloEngine`).
/// Cancellation is Swift's own `CancellationError`, which the engine treats as silent.
public enum FloError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Something a macro needs is not there: a window, a track, a button. `what` is a noun phrase, for example "the Mix window".
    case notFound(String)
    /// A macro ran itself through nested calls. `path` is the chain of macro IDs, for example "a -> b -> a".
    case cycle(path: String)

    public var description: String {
        switch self {
        case .notFound(let what): "not found: \(what)"
        case .cycle(let path): "macro cycle: \(path)"
        }
    }
}

extension Optional {
    /// The value, or `FloError.notFound(what)` when it is missing. For lookups a macro cannot continue without.
    public func required(_ what: @autoclosure () -> String) throws -> Wrapped {
        guard let self else { throw FloError.notFound(what()) }
        return self
    }
}
