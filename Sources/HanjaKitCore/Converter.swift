import Foundation

/// Entry point of the conversion engine. Pure: no UI, no AppKit.
///
/// Routes a Hangul *syllable* to Hanja candidates (with gloss) and a single *jamo* to
/// KS X 1001 symbols.
public struct Converter {
    private let hanja: HanjaTable
    private let symbols: SymbolTable

    public init(hanja: HanjaTable, symbols: SymbolTable) {
        self.hanja = hanja
        self.symbols = symbols
    }

    /// A converter wired to the bundled data tables.
    public static func bundled() throws -> Converter {
        Converter(hanja: try HanjaTable.bundled(), symbols: try SymbolTable.bundled())
    }

    /// Candidates for a reading:
    /// - `.syllable` → Hanja, frequency-ordered, with optional gloss
    /// - `.jamo`     → KS X 1001 symbols
    /// - `.other`    → none
    public func candidates(for input: String, halfwidthSymbols: Bool = false) -> [Candidate] {
        switch HangulUtil.classify(input) {
        case .syllable:
            return hanja.entries(for: input).map {
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
