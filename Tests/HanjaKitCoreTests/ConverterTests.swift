import XCTest
@testable import HanjaKitCore

final class ConverterTests: XCTestCase {
    private func makeConverter() throws -> Converter { try Converter.bundled() }

    func testSyllableReturnsHanjaCandidatesWithGloss() throws {
        let result = try makeConverter().candidates(for: "한")
        XCTAssertTrue(result.contains { $0.value == "韓" && $0.kind == .hanja })
        XCTAssertTrue(result.contains { $0.value == "漢" })
        // Common Hanja carry a Korean gloss (訓音).
        XCTAssertNotNil(result.first { $0.value == "韓" }?.gloss)
    }

    func testFrequentHanjaComeFirst() throws {
        // libhangul orders each reading by frequency, so 韓 leads the 한 candidates.
        XCTAssertEqual(try makeConverter().candidates(for: "한").first?.value, "韓")
    }

    func testJamoReturnsSymbolCandidates() throws {
        let result = try makeConverter().candidates(for: "ㅁ")
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy { $0.kind == .symbol })
    }

    func testEmptyInputReturnsNoCandidates() throws {
        XCTAssertTrue(try makeConverter().candidates(for: "").isEmpty)
    }

    func testSymbolLayoutCoversConsonants() throws {
        let converter = try makeConverter()
        for jamo in ["ㄱ", "ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅅ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ", "ㄲ", "ㄸ", "ㅃ", "ㅆ"] {
            XCTAssertFalse(converter.candidates(for: jamo).isEmpty, "expected KS X 1001 symbols for \(jamo)")
        }
    }

    func testHalfwidthFoldsFullwidthSymbols() throws {
        let converter = try makeConverter()
        let full = converter.candidates(for: "ㅈ").map(\.value)               // ０１２… fullwidth digits
        let half = converter.candidates(for: "ㅈ", halfwidthSymbols: true).map(\.value)
        XCTAssertTrue(full.contains("０") && !full.contains("0"))
        XCTAssertTrue(half.contains("0") && !half.contains("０"))
    }

    func testHalfwidthLeavesNonAsciiSymbols() throws {
        let half = try makeConverter().candidates(for: "ㅁ", halfwidthSymbols: true).map(\.value)
        XCTAssertTrue(half.contains("※"), "non-ASCII symbols stay unchanged under halfwidth folding")
    }

    func testWordCandidatesFromTable() throws {
        let words = WordTable.parse("한자:漢字:\n한자:漢子:")
        let result = try makeConverter().candidates(forWord: "한자", using: words)
        XCTAssertEqual(result.map(\.value), ["漢字", "漢子"])
        XCTAssertTrue(result.allSatisfy { $0.kind == .hanja })
    }

    func testDecompositionReturnsColumnPerSyllable() throws {
        let columns = try makeConverter().decomposition(of: "한자")
        XCTAssertEqual(columns.count, 2)
        XCTAssertEqual(columns[0].first?.value, "韓") // 한 → 韓 leads (frequency order)
        XCTAssertFalse(columns[1].isEmpty)             // 자 → has Hanja candidates
    }
}
