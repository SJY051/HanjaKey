import Foundation

/// Entry point of the conversion engine. Pure: no UI, no AppKit.
///
/// Routes a Hangul *syllable* to Hanja candidates and a single *jamo* to KS X 1001 symbols.
public struct Converter {
    private let unihan: UnihanTable
    private let symbols: SymbolTable

    public init(unihan: UnihanTable, symbols: SymbolTable) {
        self.unihan = unihan
        self.symbols = symbols
    }

    /// A converter wired to the bundled data tables.
    public static func bundled() throws -> Converter {
        Converter(unihan: try UnihanTable.bundled(), symbols: try SymbolTable.bundled())
    }

    /// Candidates for a reading.
    ///
    /// TODO: implement.
    /// - `.syllable` → `unihan.hanja(for:)` mapped to `Candidate(kind: .hanja)`
    /// - `.jamo`     → `symbols.symbols(for:)` mapped to `Candidate(kind: .symbol)`
    /// - `.other`    → `[]`
    public func candidates(for input: String) -> [Candidate] {
        switch HangulUtil.classify(input) {
        case .syllable:
            return unihan.hanja(for: input).map { Candidate(value: $0, kind: .hanja) }
        case .jamo:
            return symbols.symbols(for: input).map { Candidate(value: $0, kind: .symbol) }
        case .other:
            return []
        }
    }
}
