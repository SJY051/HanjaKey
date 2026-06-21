import Foundation

/// The active token at the caret, chosen from a captured trailing-Hangul run (spec 007).
/// `selectBack` for in-place replacement = `text.count`.
public enum Segment: Equatable, Sendable {
    /// A single character → `Converter.candidates(for:)` routes it (jamo → KS X 1001 symbol,
    /// syllable → Hanja). Covers a trailing lone jamo and a lone syllable.
    case single(String)
    /// A multi-syllable dictionary suffix → `Converter.candidates(forWord:)`.
    case word(String)
    /// A multi-syllable run with no dictionary word → per-syllable decomposition build.
    case decompose(String)

    /// The text span this token covers (what candidates are for, and what insertion replaces).
    public var text: String {
        switch self {
        case .single(let s), .word(let s), .decompose(let s): return s
        }
    }
}

/// Decides the active token at the caret for a captured trailing-Hangul run — the boundary logic that
/// routing and the replace-extent depend on (spec 007). Pure + unit-tested; the app feeds it the ⌘C-captured
/// run so it works the same in native, Electron, and browser targets.
public enum Segmenter {
    /// Segment a captured run (trailing Hangul: syllables, optionally a trailing compatibility jamo).
    ///
    /// 1. (Q1) A trailing lone **compatibility jamo** is its own symbol token — only the jamo, regardless
    ///    of any syllables before it (`가ㄱ` → `ㄱ`).
    /// 2. (Q2) Otherwise the **longest dictionary-word suffix** is a word (`나는한국` → `한국`).
    /// 3. Otherwise a lone **single syllable**, or **per-syllable decomposition** for a multi-syllable
    ///    non-word run (never silently collapse to the last single syllable — spec 007 bug B).
    ///
    /// `words` is an autoclosure so the (heavy, lazily-loaded) word table is only consulted for a
    /// multi-syllable, non-jamo run — single syllables and lone jamo never touch it.
    public static func segment(_ run: String, words: @autoclosure () -> WordTable) -> Segment {
        let chars = Array(run)
        guard let last = chars.last else { return .single("") }
        if case .jamo = HangulUtil.classify(String(last)) {
            return .single(String(last))                       // (1) trailing lone jamo → symbol token
        }
        if chars.count >= 2, let suffix = words().longestWordSuffix(of: run) {
            return .word(suffix)                               // (2) longest dictionary word suffix
        }
        return chars.count <= 1 ? .single(run) : .decompose(run) // (3) single syllable / decomposition
    }
}
