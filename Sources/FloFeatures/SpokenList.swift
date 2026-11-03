/// How the JXA spoke a list: each item followed by ". ", the last one too, for example "Kick. Snare. ".
enum SpokenList {
    static func sentences(_ items: [String]) -> String {
        items.map { $0 + ". " }.joined()
    }
}
