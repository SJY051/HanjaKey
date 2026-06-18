import Foundation

/// A single conversion result shown in the popup: a Hanja or a special symbol.
public struct Candidate: Equatable, Hashable, Sendable {
    public enum Kind: Sendable {
        case hanja
        case symbol
    }

    public let value: String
    public let kind: Kind
    /// Optional gloss/meaning (e.g. "한국 한"). Unihan kHangul has no gloss; reserved for later.
    public let gloss: String?

    public init(value: String, kind: Kind, gloss: String? = nil) {
        self.value = value
        self.kind = kind
        self.gloss = gloss
    }
}
