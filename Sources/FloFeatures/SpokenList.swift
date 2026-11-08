/// How the JXA spoke a list: each item followed by ". ", the last one too, for example "Kick. Snare. ".
enum SpokenList {
    static func sentences(_ items: [String]) -> String {
        items.map { $0 + ". " }.joined()
    }
}

extension String {
    /// `replacement` when the string is empty, like the JXA's `if (value == "") value = "None"`.
    func orIfEmpty(_ replacement: String) -> String { isEmpty ? replacement : self }
}
