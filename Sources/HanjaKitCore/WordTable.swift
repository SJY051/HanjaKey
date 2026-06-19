import Foundation

/// Multi-syllable Hangul reading → ordered Hanja-WORD candidates with optional gloss.
///
/// Source: libhangul `hanja.txt`, filtered to 2–6 syllable entries (`음:한자:뜻`). Large (~235k
/// entries), so the app loads it lazily on the first multi-syllable conversion.
///
/// Entries are kept in source order; ranking (syllable-frequency score + gloss tiebreaker) is applied
/// by `Converter.candidates(forWord:using:)`, which holds the single-Hanja frequency table.
public struct WordTable {
    public struct Entry: Equatable, Sendable {
        public let hanja: String
        public let gloss: String?

        public init(hanja: String, gloss: String?) {
            self.hanja = hanja
            self.gloss = gloss
        }
    }

    private let readingToEntries: [String: [Entry]]

    public init(readingToEntries: [String: [Entry]]) {
        self.readingToEntries = readingToEntries
    }

    /// Entries for a reading: gloss-bearing first then gloss-less, each in original order. Empty if none.
    public func entries(for reading: String) -> [Entry] {
        readingToEntries[reading] ?? []
    }

    /// Parse `음:한자:뜻` lines (blank/`#` skipped), grouped by reading in source order.
    /// Ranking is applied later by `Converter.candidates(forWord:using:)`.
    public static func parse(_ text: String) -> WordTable {
        var map: [String: [Entry]] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let cols = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard cols.count >= 2 else { continue }
            let reading = String(cols[0])
            let hanja = String(cols[1])
            guard !reading.isEmpty, !hanja.isEmpty else { continue }
            let glossText = cols.count >= 3
                ? String(cols[2]).trimmingCharacters(in: .whitespaces)
                : ""
            map[reading, default: []].append(Entry(hanja: hanja, gloss: glossText.isEmpty ? nil : glossText))
        }
        return WordTable(readingToEntries: map)
    }

    /// Build from the bundled word file. Heavy — load lazily (e.g. a `static let` touched on first use).
    public static func bundled() throws -> WordTable {
        guard let url = Bundle.module.url(
            forResource: "hanja_words",
            withExtension: "txt",
            subdirectory: "Resources"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return parse(try String(contentsOf: url, encoding: .utf8))
    }
}
