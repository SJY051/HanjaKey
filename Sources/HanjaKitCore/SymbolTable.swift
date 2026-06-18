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
        let map = try JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: url))
        return SymbolTable(jamoToSymbols: map)
    }
}
