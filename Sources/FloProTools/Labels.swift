extension String {
    /// Removes or replaces the first match only, as JavaScript's `String.replace` with a string pattern did. Pro Tools puts a control's setting after its label, and the JXA stripped labels this way, so spoken text keeps the spaces and line breaks it had.
    public func replacingFirst(_ target: String, with replacement: String) -> String {
        guard let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}
