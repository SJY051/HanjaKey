import Foundation

/// Hangul reading → ordered Hanja candidates, each with an optional Korean gloss (訓音).
///
/// Source: libhangul `hanja.txt`, filtered to single-syllable entries (`음:한자:뜻`).
/// libhangul lists each reading's Hanja in frequency / representativeness order, so the most
/// common Hanja come first — matching the Windows Hanja-key ordering. We preserve that order.
/// The gloss (e.g. `나라 이름 한`) is empty for many rare characters.
public struct HanjaTable {
    /// One Hanja candidate for a reading: the character and its optional gloss.
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

    /// Entries for a reading, in table (frequency) order. Empty if none.
    public func entries(for reading: String) -> [Entry] {
        readingToEntries[reading] ?? []
    }

    /// Frequency rank of `hanja` for `reading` (0 = most common in the table), or nil if absent.
    public func rank(of hanja: String, for reading: String) -> Int? {
        entries(for: reading).firstIndex { $0.hanja == hanja }
    }

    /// Parse `hanja.txt` content into the reading → entries map.
    ///
    /// Line format: `음:한자:뜻` (the gloss may be empty). Blank lines and `#` comments are
    /// skipped. First-seen order is preserved per reading.
    public static func parse(_ text: String) -> HanjaTable {
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
            let entry = Entry(hanja: hanja, gloss: glossText.isEmpty ? nil : glossText)
            map[reading, default: []].append(entry)
        }
        return HanjaTable(readingToEntries: map)
    }

    /// Build from the bundled `hanja.txt`.
    public static func bundled() throws -> HanjaTable {
        guard let url = Bundle.module.url(
            forResource: "hanja",
            withExtension: "txt",
            subdirectory: "Resources"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return parse(try String(contentsOf: url, encoding: .utf8))
    }
}
