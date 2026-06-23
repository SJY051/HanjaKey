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

    /// Outcome of reading the overlay: a hand-edited JSON we must not silently clobber when it's broken.
    enum LoadOutcome {
        case ok([String: [String]])
        case missing                  // no file yet → treat as an empty overlay
        case malformed(Error)         // file exists but unreadable/invalid → surface; do NOT overwrite
    }

    /// Read the overlay, distinguishing "no file" from "broken file" (the latter must be surfaced so a
    /// later save doesn't overwrite the user's recoverable content).
    static func loadOutcome() -> LoadOutcome {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return .missing }
        do {
            return .ok(try SymbolTable.parseMap(try Data(contentsOf: url)))
        } catch {
            return .malformed(error)
        }
    }

    /// Convenience for the converter overlay: missing or malformed → empty (conversion still works).
    static func load() -> [String: [String]] {
        if case .ok(let map) = loadOutcome() { return map }
        return [:]
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

    /// Save the overlay back to disk (pretty-printed, sorted), dropping empty entries. Throws on failure
    /// and writes atomically so a failed write can't truncate the existing file.
    static func save(_ map: [String: [String]]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(map.filter { !$0.value.isEmpty })
        try data.write(to: fileURL, options: .atomic)
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
