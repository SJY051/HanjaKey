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
    public func candidates(for input: String) -> [Candidate] {
        switch HangulUtil.classify(input) {
        case .syllable:
            return hanja.entries(for: input).map {
                Candidate(value: $0.hanja, kind: .hanja, gloss: $0.gloss)
            }
        case .jamo:
            return symbols.symbols(for: input).map { Candidate(value: $0, kind: .symbol) }
        case .other:
            return []
        }
    }
}
