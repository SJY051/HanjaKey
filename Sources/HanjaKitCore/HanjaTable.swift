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

    /// Overlay glosses from `other`, filling EMPTY 훈음 only. For an entry whose gloss is nil, if `other`
    /// has the same `(reading, hanja)` with a gloss, adopt it. Never overrides a non-nil gloss, never
    /// reorders, and never adds a `(reading, hanja)` absent from self — the single-Hanja candidate list
    /// and its frequency order stay exactly libhangul's; only blank meanings get filled. (Spec 004.)
    public func merging(_ other: HanjaTable) -> HanjaTable {
        let incoming = other.readingToEntries
        var map: [String: [Entry]] = [:]
        map.reserveCapacity(readingToEntries.count)
        for (reading, entries) in readingToEntries {
            guard let others = incoming[reading] else {
                map[reading] = entries
                continue
            }
            map[reading] = entries.map { entry in
                guard entry.gloss == nil,
                      let gloss = others.first(where: { $0.hanja == entry.hanja })?.gloss
                else { return entry }
                return Entry(hanja: entry.hanja, gloss: gloss)
            }
        }
        return HanjaTable(readingToEntries: map)
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

    /// Build from the bundled `hanja.txt`, then overlay the license-clean gloss sources (spec 004),
    /// filling empty 훈음 only. Each overlay is optional — a missing file just skips that source.
    public static func bundled() throws -> HanjaTable {
        var table = parse(try loadBundled("hanja", subdirectory: "Resources"))
        for subdirectory in [
            "Resources/data/hanja-gloss-wiktionary",
            "Resources/data/hanja-gloss-hanjadb",
        ] {
            if let text = try? loadBundled("hanja_gloss", subdirectory: subdirectory) {
                table = table.merging(parse(text))
            }
        }
        return table
    }

    private static func loadBundled(_ resource: String, subdirectory: String) throws -> String {
        guard let url = Bundle.module.url(
            forResource: resource,
            withExtension: "txt",
            subdirectory: subdirectory
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}
