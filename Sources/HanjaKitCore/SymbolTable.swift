import Foundation

/// KS X 1001 special symbols offered for a single Hangul jamo (e.g. ㅁ → ※ ◎ □ …).
public struct SymbolTable {
    private let jamoToSymbols: [String: [String]]

    public init(jamoToSymbols: [String: [String]]) {
        self.jamoToSymbols = jamoToSymbols
    }

    /// Symbols for a jamo, in table order. Empty if none.
    public func symbols(for jamo: String) -> [String] {
        jamoToSymbols[jamo] ?? []
    }

    /// Build from the bundled JSON table (jamo → [symbol]).
    public static func bundled() throws -> SymbolTable {
        guard let url = Bundle.module.url(
            forResource: "ks_x_1001_symbols",
            withExtension: "json",
            subdirectory: "Resources"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return SymbolTable(jamoToSymbols: try parseMap(Data(contentsOf: url)))
    }

    /// Decode a jamo → [symbol] JSON map (used for both the bundled table and a user-supplied one).
    public static func parseMap(_ data: Data) throws -> [String: [String]] {
        try JSONDecoder().decode([String: [String]].self, from: data)
    }

    /// A copy with `overlay` merged in: each overlay jamo REPLACES the entry for that jamo, so a
    /// user can fill empty jamo (e.g. vowels ㅏㅐ…) or override a consonant's set. Empty arrays are
    /// ignored, so a stray `"ㅏ": []` won't blank out anything.
    public func merging(_ overlay: [String: [String]]) -> SymbolTable {
        var map = jamoToSymbols
        for (jamo, symbols) in overlay where !symbols.isEmpty {
            map[jamo] = symbols
        }
        return SymbolTable(jamoToSymbols: map)
    }
}
