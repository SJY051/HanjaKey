import Foundation

/// Inverse index built from the Unicode Unihan `kHangul` data: Hangul reading → [Hanja].
///
/// Source line format (UAX #38, `Unihan_Readings.txt`):
/// ```
/// U+6F22\tkHangul\t한:0E
/// ```
/// The value column is a space-separated list of readings; each reading may carry a
/// source-tag suffix `:....` (e.g. `:0E` educational, `:0N` name-use) that MUST be stripped.
public struct UnihanTable {
    private let readingToHanja: [String: [String]]

    public init(readingToHanja: [String: [String]]) {
        self.readingToHanja = readingToHanja
    }

    /// Hanja for a Hangul reading, in table order. Empty if none.
    public func hanja(for reading: String) -> [String] {
        readingToHanja[reading] ?? []
    }

    /// Parse `Unihan_Readings.txt` content into the inverse map.
    ///
    /// TODO: implement.
    /// For each line matching `U+XXXX\tkHangul\t<readings>`:
    ///   1. decode `U+XXXX` → the Han character (Unicode.Scalar)
    ///   2. split `<readings>` on whitespace
    ///   3. for each reading, drop everything from the first `:` (the source tag)
    ///   4. append the Han char to `map[reading]` (preserve first-seen order)
    /// Skip blank/comment (`#`) and non-`kHangul` lines.
    public static func parse(_ text: String) -> UnihanTable {
        var map: [String: [String]] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let cols = line.split(separator: "\t")
            guard cols.count >= 3, cols[1] == "kHangul" else { continue }
            // Decode "U+XXXX" → the Han character.
            let cp = cols[0]
            guard cp.hasPrefix("U+"),
                  let codepoint = UInt32(cp.dropFirst(2), radix: 16),
                  let scalar = Unicode.Scalar(codepoint) else { continue }
            let hanja = String(scalar)
            // Each reading: drop the ":tag" source suffix, then index reading → [Hanja].
            for token in cols[2].split(separator: " ") {
                let reading = String(token.split(separator: ":").first ?? token)
                guard !reading.isEmpty else { continue }
                map[reading, default: []].append(hanja)
            }
        }
        return UnihanTable(readingToHanja: map)
    }

    /// Build from the bundled sample data file.
    public static func bundled() throws -> UnihanTable {
        guard let url = Bundle.module.url(
            forResource: "Unihan_Readings.sample",
            withExtension: "txt",
            subdirectory: "Resources"
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return parse(try String(contentsOf: url, encoding: .utf8))
    }
}
