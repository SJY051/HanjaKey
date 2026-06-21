import XCTest
@testable import HanjaKitCore

final class SegmenterTests: XCTestCase {
    /// Build a WordTable from reading → [hanja] (glossless) for routing tests.
    private func words(_ entries: [String: [String]]) -> WordTable {
        var map: [String: [WordTable.Entry]] = [:]
        for (reading, hanjas) in entries {
            map[reading] = hanjas.map { WordTable.Entry(hanja: $0, gloss: nil) }
        }
        return WordTable(readingToEntries: map)
    }

    // Q1: a trailing lone compatibility jamo is its own symbol token.
    func testTrailingLoneJamoIsItsOwnToken() {
        let w = words(["한국": ["韓國"]])
        XCTAssertEqual(Segmenter.segment("가ㄱ", words: w), .single("ㄱ"))
        XCTAssertEqual(Segmenter.segment("ㄱ", words: w), .single("ㄱ"))
        XCTAssertEqual(Segmenter.segment("한국ㅁ", words: w), .single("ㅁ")) // word before, jamo wins
    }

    func testLoneSyllableIsSingle() {
        XCTAssertEqual(Segmenter.segment("가", words: words([:])), .single("가"))
    }

    // Q2: longest dictionary-word suffix.
    func testWholeRunIsAWord() {
        let w = words(["대한민국": ["大韓民國"]])
        XCTAssertEqual(Segmenter.segment("대한민국", words: w), .word("대한민국"))
    }

    func testLongestSuffixAbsorbsOvercapture() {
        let w = words(["한국": ["韓國"]])
        XCTAssertEqual(Segmenter.segment("나는한국", words: w), .word("한국"))
    }

    func testWholeWordWinsOverShorterEmbeddedSuffix() {
        let w = words(["대한민국": ["大韓民國"], "민국": ["民國"]])
        XCTAssertEqual(Segmenter.segment("대한민국", words: w), .word("대한민국")) // longest first
    }

    func testEmbeddedWordWhenWholeIsNotOne() {
        let w = words(["민국": ["民國"]]) // 대한민국 itself absent → fall to the longest known suffix
        XCTAssertEqual(Segmenter.segment("대한민국", words: w), .word("민국"))
    }

    // Q2 fallback: multi-syllable non-word → decomposition, NOT last-syllable single (bug B).
    func testMultiSyllableNonWordDecomposes() {
        XCTAssertEqual(Segmenter.segment("갑을병", words: words([:])), .decompose("갑을병"))
    }

    func testEmptyRunIsEmptySingle() {
        XCTAssertEqual(Segmenter.segment("", words: words([:])), .single(""))
    }
}

final class WordTableSuffixTests: XCTestCase {
    func testLongestWordSuffix() {
        let w = WordTable(readingToEntries: ["한국": [.init(hanja: "韓國", gloss: nil)]])
        XCTAssertEqual(w.longestWordSuffix(of: "나는한국"), "한국")
        XCTAssertEqual(w.longestWordSuffix(of: "한국"), "한국")
        XCTAssertNil(w.longestWordSuffix(of: "갑을병"))
        XCTAssertNil(w.longestWordSuffix(of: "가"))   // length < 2 is never a word
    }
}
