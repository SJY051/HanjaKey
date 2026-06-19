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

    /// Whole-word Hanja candidates for a multi-syllable reading, using a (lazily loaded) word table.
    public func candidates(forWord word: String, using words: WordTable) -> [Candidate] {
        words.entries(for: word).map { Candidate(value: $0.hanja, kind: .hanja, gloss: $0.gloss) }
    }

    /// Per-syllable decomposition: the single-syllable Hanja candidates for each syllable, in order.
    /// Used as a fallback when a word isn't in the dictionary (the UI offers a column per syllable).
    public func decomposition(of word: String) -> [[Candidate]] {
        word.map { candidates(for: String($0)) }
    }
}
