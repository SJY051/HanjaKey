import Foundation

/// Classification of a single-character input.
public enum HangulInput: Equatable {
    /// A precomposed Hangul syllable (가–힣, U+AC00…U+D7A3).
    case syllable(Character)
    /// A compatibility jamo (ㄱ–ㅎ / ㅏ–ㅣ, U+3131…U+3163).
    case jamo(Character)
    /// Anything else (Latin, multi-char, empty, …).
    case other
}

public enum HangulUtil {
    /// Classify a (typically single-character) input string.
    ///
    /// - syllable: scalar in 0xAC00...0xD7A3
    /// - jamo:     scalar in 0x3131...0x3163 (Hangul Compatibility Jamo)
    /// - other:    everything else, including empty and multi-character input
    public static func classify(_ input: String) -> HangulInput {
        let scalars = Array(input.unicodeScalars)
        guard scalars.count == 1, let scalar = scalars.first else { return .other }
        switch scalar.value {
        case 0xAC00...0xD7A3: return .syllable(Character(scalar)) // precomposed Hangul syllables
        case 0x3131...0x3163: return .jamo(Character(scalar))     // Hangul Compatibility Jamo
        default:              return .other
        }
    }
}
