import Foundation

/// Hangul reading → per-Hanja usage frequency, from the 국립국어원 현대 국어 사용 빈도 조사 (2002).
///
/// This is the *ranking signal* for multi-syllable homophone words (spec 003-ranking-data, M1). It does
/// NOT define the candidate set — that stays the libhangul `WordTable` inventory — it only reorders the
/// candidates by real usage. Readings absent here keep the 002 ordering (no regression).
///
/// Source: KOGL 제1유형 (출처표시), 국립국어원 — see `Resources/data/nikl-freq/LICENSE-DATA.md` and the
/// repo-root `THIRD_PARTY_DATA.md`. Built from the corpus result files by `scripts/build_freq.py`.
/// Large-ish, so load it lazily (like `WordTable`) on the first multi-syllable conversion.
public struct FreqTable: Sendable {
    private let readingToFreq: [String: [String: Int]]

    public init(readingToFreq: [String: [String: Int]]) {
        self.readingToFreq = readingToFreq
    }

    /// Corpus frequency of `hanja` written for `reading`, or nil if the corpus has no count for it.
    public func frequency(of hanja: String, for reading: String) -> Int? {
        readingToFreq[reading]?[hanja]
    }

    /// Whether the corpus carries ANY frequency data for this reading. Used to choose
    /// frequency-ordering vs. the 002 fallback (an absent reading must behave exactly like 002).
    public func hasReading(_ reading: String) -> Bool {
        readingToFreq[reading] != nil
    }

    /// Parse `읽기:한자:빈도` lines (blank / `#` skipped), grouped by reading. Malformed rows and
    /// non-integer frequencies are skipped defensively (mirrors `WordTable.parse`). The build output is
    /// already de-duplicated per (reading, hanja), so last value wins on the rare duplicate.
    public static func parse(_ text: String) -> FreqTable {
        var map: [String: [String: Int]] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let cols = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard cols.count == 3 else { continue }
            let reading = String(cols[0])
            let hanja = String(cols[1])
            guard !reading.isEmpty, !hanja.isEmpty,
                  let freq = Int(cols[2].trimmingCharacters(in: .whitespaces)) else { continue }
            map[reading, default: [:]][hanja] = freq
        }
        return FreqTable(readingToFreq: map)
    }

    /// Build from the bundled frequency file. Heavy — load lazily (e.g. a `static let` touched on first use).
    ///
    /// NOTE: `hanja_freq.txt` is a BUILD ARTIFACT produced by `scripts/build_freq.py`; it does not exist
    /// yet at scaffold time, so this throws until the build step has run. Callers must load lazily.
    public static func bundled() throws -> FreqTable {
        guard let url = Bundle.module.url(
            forResource: "hanja_freq",
            withExtension: "txt",
            subdirectory: "Resources/data/nikl-freq"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return parse(try String(contentsOf: url, encoding: .utf8))
    }
}
