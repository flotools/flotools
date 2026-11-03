/// What Pro Tools puts before the name of a selected row in the Track List and the clip list.
let selectedRowPrefix = "Selected. "

extension String {
    /// Removes or replaces the first match only, as JavaScript's `String.replace` with a string pattern did. The JXA stripped Pro Tools labels and replaced note accidentals this way, so spoken text keeps the spaces and line breaks it had.
    public func replacingFirst(_ target: String, with replacement: String) -> String {
        guard let range = range(of: target) else { return self }
        return replacingCharacters(in: range, with: replacement)
    }
}
