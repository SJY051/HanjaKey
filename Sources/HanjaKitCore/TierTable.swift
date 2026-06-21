import Foundation

/// Per-reading display ordering for single-Hanja candidates (spec 005 M2).
///
/// Built by `scripts/build_tiers.py` from the ranking swarm and bundled as
/// `Resources/data/curation-swarm/tiers.txt` (`읽기:한자:티어:글로스`, already sorted per reading by tier
/// then rank — so the file's line order *is* the display order). Used ONLY to order the single-syllable
/// candidate list; it deliberately does NOT touch `HanjaTable`'s libhangul frequency order, which the
/// multi-syllable word scorer (`HanjaTable.rank(of:for:)`) depends on. Readings absent here (≤20
/// candidates, never ranked) fall back to the rule-based M1 ordering in `Converter`.
public struct TierTable: Sendable {
    /// reading → (hanja → position). Lower position = shown earlier (0 = best).
    private let positions: [String: [String: Int]]

    public init(positions: [String: [String: Int]]) {
        self.positions = positions
    }

    /// Ranked position of `hanja` within `reading`, or nil if the reading wasn't ranked (or the
    /// character isn't listed). Lower = earlier.
    public func position(of hanja: String, for reading: String) -> Int? {
        positions[reading]?[hanja]
    }

    /// Whether `reading` has a ranked ordering (i.e. the swarm processed it).
    public func hasReading(_ reading: String) -> Bool {
        positions[reading] != nil
    }

    /// Parse `tiers.txt`. Line: `읽기:한자:티어:글로스` (tier/gloss are unused for ordering — the file's
    /// per-reading line order already encodes (tier, rank)). Blank lines and `#` comments are skipped;
    /// each character's first-seen index within its reading becomes its position.
    public static func parse(_ text: String) -> TierTable {
        var positions: [String: [String: Int]] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let cols = line.split(separator: ":", maxSplits: 3, omittingEmptySubsequences: false)
            guard cols.count >= 2 else { continue }
            let reading = String(cols[0])
            let hanja = String(cols[1])
            guard !reading.isEmpty, !hanja.isEmpty else { continue }
            var byHanja = positions[reading] ?? [:]
            if byHanja[hanja] == nil { byHanja[hanja] = byHanja.count }
            positions[reading] = byHanja
        }
        return TierTable(positions: positions)
    }

    /// Build from the bundled `curation-swarm/tiers.txt`. A missing file yields an empty table, so the
    /// engine simply falls back to the rule-based ordering everywhere.
    public static func bundled() -> TierTable {
        guard let url = Bundle.module.url(
            forResource: "tiers",
            withExtension: "txt",
            subdirectory: "Resources/data/curation-swarm"
        ), let text = try? String(contentsOf: url, encoding: .utf8) else {
            return TierTable(positions: [:])
        }
        return parse(text)
    }
}
