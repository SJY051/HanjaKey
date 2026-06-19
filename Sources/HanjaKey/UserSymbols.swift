import Foundation
import HanjaKitCore

/// A user-supplied jamo → [symbol] overlay, stored as hand-editable JSON in Application Support.
/// Merged on top of the bundled KS X 1001 table, so users can fill empty jamo (e.g. vowels, which
/// the real Hanja key doesn't use) or override a consonant's set.
enum UserSymbols {
    static var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HanjaKey", isDirectory: true)
        return base.appendingPathComponent("symbols.json")
    }

    /// Load the overlay; empty if missing or malformed (defensive — it's a hand-edited file).
    static func load() -> [String: [String]] {
        guard let data = try? Data(contentsOf: fileURL),
              let map = try? SymbolTable.parseMap(data) else { return [:] }
        return map
    }

    /// On first run, write a starter template with a few vowel examples so the file is discoverable.
    static func ensureTemplate() {
        let url = fileURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? Data(template.utf8).write(to: url)
    }

    /// Save the overlay back to disk (pretty-printed, sorted), dropping empty entries.
    static func save(_ map: [String: [String]]) {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(map.filter { !$0.value.isEmpty }) {
            try? data.write(to: fileURL)
        }
    }

    /// Starter content: vowels (unused by the real Hanja key) prefilled as examples to edit.
    private static let template = """
    {
      "ㅏ": ["←", "↑", "→", "↓", "↖", "↗", "↘", "↙", "↔", "↕"],
      "ㅗ": ["★", "☆", "♥", "♡", "♦", "♣", "♠", "✓", "✗", "✦"],
      "ㅜ": ["☀", "☁", "☂", "☃", "❄", "⚡", "✿", "❀", "☘", "✪"]
    }
    """
}
