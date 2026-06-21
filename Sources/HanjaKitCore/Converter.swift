import Foundation

/// Entry point of the conversion engine. Pure: no UI, no AppKit.
///
/// Routes a Hangul *syllable* to Hanja candidates (with gloss) and a single *jamo* to
/// KS X 1001 symbols.
public struct Converter {
    private let hanja: HanjaTable
    private let symbols: SymbolTable
    private let tiers: TierTable

    public init(hanja: HanjaTable, symbols: SymbolTable, tiers: TierTable = TierTable(positions: [:])) {
        self.hanja = hanja
        self.symbols = symbols
        self.tiers = tiers
    }

    /// A converter wired to the bundled data tables.
    public static func bundled() throws -> Converter {
        Converter(
            hanja: try HanjaTable.bundled(),
            symbols: try SymbolTable.bundled(),
            tiers: TierTable.bundled()
        )
    }

    /// Candidates for a reading:
    /// - `.syllable` → Hanja, frequency-ordered, with optional gloss
    /// - `.jamo`     → KS X 1001 symbols
    /// - `.other`    → none
    public func candidates(for input: String, halfwidthSymbols: Bool = false) -> [Candidate] {
        switch HangulUtil.classify(input) {
        case .syllable:
            return curate(hanja.entries(for: input), for: input).map {
                Candidate(value: $0.hanja, kind: .hanja, gloss: $0.gloss)
            }
        case .jamo:
            return symbols.symbols(for: input).map {
                Candidate(value: halfwidthSymbols ? Self.foldToHalfwidth($0) : $0, kind: .symbol)
            }
        case .other:
            return []
        }
    }

    /// Order single-Hanja candidates for display. For a reading the M2 swarm ranked (spec 005), use the
    /// bundled tier/rank order (`tiers.txt`); otherwise fall back to the M1 rule. Never drops a candidate —
    /// the full set is reordered, and the UI keeps the tail one affordance away (the grid).
    func curate(_ entries: [HanjaTable.Entry], for reading: String) -> [HanjaTable.Entry] {
        guard tiers.hasReading(reading) else { return Self.curateByRule(entries) }
        return entries.enumerated()
            .sorted { lhs, rhs in
                let pl = tiers.position(of: lhs.element.hanja, for: reading) ?? Int.max
                let pr = tiers.position(of: rhs.element.hanja, for: reading) ?? Int.max
                if pl != pr { return pl < pr }
                return lhs.offset < rhs.offset // a char missing from tiers keeps libhangul order, at the back
            }
            .map(\.element)
    }

    /// M1 fallback (spec 005 v1) for readings the swarm never ranked (≤20 candidates): stable-partition
    /// into clean-gloss → empty-gloss → variant-pointer-gloss, preserving libhangul's order within each
    /// tier. Demotes explicit variants (同字/略字/俗字/簡體) and glossless rares below the meaning-bearing.
    static func curateByRule(_ entries: [HanjaTable.Entry]) -> [HanjaTable.Entry] {
        func tier(_ entry: HanjaTable.Entry) -> Int {
            guard let gloss = entry.gloss, !gloss.isEmpty else { return 1 } // no meaning → middle
            return isVariantPointer(gloss) ? 2 : 0                          // variant pointer → back
        }
        return entries.enumerated()
            .sorted { (tier($0.element), $0.offset) < (tier($1.element), $1.offset) }
            .map(\.element)
    }

    /// A gloss that merely points at another character ("歌와 同字", "假의 略字", 俗字, 簡體) — i.e. a
    /// variant form we demote in favor of its canonical character.
    static func isVariantPointer(_ gloss: String) -> Bool {
        gloss.contains("同字") || gloss.contains("略字") || gloss.contains("俗字") || gloss.contains("簡體")
    }

    /// Fold fullwidth ASCII-range characters (！０Ａ …) and the ideographic space to their
    /// halfwidth equivalents; leave non-ASCII symbols (※ ☆ …) unchanged.
    static func foldToHalfwidth(_ s: String) -> String {
        String(s.unicodeScalars.map { scalar -> Character in
            switch scalar.value {
            case 0xFF01...0xFF5E: return Character(Unicode.Scalar(scalar.value - 0xFEE0)!)
            case 0x3000: return " "
            default: return Character(scalar)
            }
        })
    }

    /// Whole-word Hanja candidates for a multi-syllable reading, using a (lazily loaded) word table and
    /// an optional corpus-frequency table.
    ///
    /// When `freq` has the reading, candidates are ordered by DESCENDING corpus frequency (국립국어원 2002,
    /// spec 003); Hanja with no count fall to the back, ordered by the 002 heuristic. When `freq` is nil
    /// or lacks the reading, ordering is exactly the 002 heuristic: gloss-first (libhangul's "real
    /// headword" signal), then summed single-syllable frequency rank (lower = more common), then source
    /// order. The frequency table only reorders — it never drops a candidate (FR-006).
    public func candidates(forWord word: String, using words: WordTable, freq: FreqTable? = nil) -> [Candidate] {
        let readingChars = Array(word)
        func score(_ entry: WordTable.Entry) -> Int {
            let hanjaChars = Array(entry.hanja)
            guard hanjaChars.count == readingChars.count else { return Int.max }
            var total = 0
            for (reading, char) in zip(readingChars, hanjaChars) {
                guard let r = hanja.rank(of: String(char), for: String(reading)) else { return Int.max }
                total += r
            }
            return total
        }
        // 002 heuristic comparator: gloss-first, then syllable-frequency score, then source order.
        func heuristicLess(_ lhs: (offset: Int, element: WordTable.Entry),
                           _ rhs: (offset: Int, element: WordTable.Entry)) -> Bool {
            let gl = lhs.element.gloss != nil, gr = rhs.element.gloss != nil
            if gl != gr { return gl }
            let sl = score(lhs.element), sr = score(rhs.element)
            if sl != sr { return sl < sr }
            return lhs.offset < rhs.offset
        }
        let useFreq = freq?.hasReading(word) ?? false
        let ranked = words.entries(for: word).enumerated().sorted { lhs, rhs in
            if useFreq, let freq {
                let fl = freq.frequency(of: lhs.element.hanja, for: word)
                let fr = freq.frequency(of: rhs.element.hanja, for: word)
                if let fl, let fr, fl != fr { return fl > fr }   // both ranked: higher frequency first
                if (fl != nil) != (fr != nil) { return fl != nil } // one ranked: it leads the unranked
                // neither ranked (or equal) → fall through to the 002 heuristic
            }
            return heuristicLess(lhs, rhs)
        }
        return ranked.map { Candidate(value: $0.element.hanja, kind: .hanja, gloss: $0.element.gloss) }
    }

    /// Per-syllable decomposition: the single-syllable Hanja candidates for each syllable, in order.
    /// Used as a fallback when a word isn't in the dictionary (the UI offers a column per syllable).
    public func decomposition(of word: String) -> [[Candidate]] {
        word.map { candidates(for: String($0)) }
    }
}
