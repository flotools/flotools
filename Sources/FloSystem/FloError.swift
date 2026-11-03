/// The one error model. Core code throws these so the engine can log why a macro stopped and tell the user (`SpokenError` in `FloEngine`).
/// Cancellation is Swift's own `CancellationError`, which the engine treats as silent.
public enum FloError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Something a macro needs is not there: a window, a track, a button. `what` is a noun phrase, for example "the Mix window".
    case notFound(String)
    /// A macro ran itself through nested calls. `path` is the chain of macro IDs, for example "a -> b -> a".
    case cycle(path: String)
    /// VoiceOver did not take an Apple event: not running, not answering, or not permitted. `reason` says which, for the log.
    case voiceOver(String)
    /// An Accessibility call failed with an `AXError` other than "no value". `operation` is the attribute read or the action, `code` the raw `AXError`; `cannotComplete` (-25204) also covers the messaging timeout of a busy app.
    case accessibility(operation: String, code: Int32)
    /// An Accessibility read worked but gave a value of an unexpected type.
    case unexpectedValue(String)
    /// A step ran but did not have its effect. `what` is a verb phrase, for example "suspend the mix groups".
    case couldNot(String)
    /// A multi-step job stopped part way. `done` says what was done, for example "Unsoloed 2 of 5 tracks"; `cause` is why it stopped.
    indirect case incomplete(done: String, cause: FloError)

    public var description: String {
        switch self {
        case .notFound(let what): "not found: \(what)"
        case .cycle(let path): "macro cycle: \(path)"
        case .voiceOver(let reason): "VoiceOver: \(reason)"
        case .accessibility(let operation, let code): "Accessibility: \(operation) failed with AXError \(code)"
        case .unexpectedValue(let what): "unexpected value: \(what)"
        case .couldNot(let what): "could not \(what)"
        case .incomplete(let done, let cause): "\(done), then \(cause)"
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
