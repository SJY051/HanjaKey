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

    func testWordCandidatesGlossFirstThenFrequency() throws {
        // 韓國 has a gloss → first (libhangul headword signal). Among glossless entries, the lower
        // syllable-frequency score wins (寒國 ahead of 寒菊/汗國).
        let words = WordTable.parse("한국:寒國:\n한국:寒菊:\n한국:韓國:대한민국\n한국:汗國:")
        let result = try makeConverter().candidates(forWord: "한국", using: words).map(\.value)
        XCTAssertEqual(result.first, "韓國")
        XCTAssertEqual(result.dropFirst().first, "寒國")
    }

    func testDecompositionReturnsColumnPerSyllable() throws {
        let columns = try makeConverter().decomposition(of: "한자")
        XCTAssertEqual(columns.count, 2)
        XCTAssertEqual(columns[0].first?.value, "韓") // 한 → 韓 leads (frequency order)
        XCTAssertFalse(columns[1].isEmpty)             // 자 → has Hanja candidates
    }

    // MARK: - 003-M1 frequency ranking (scaffold; skipped until implemented)

    func testWordCandidatesFrequencyOrderingPrefersCommonHanja() throws {
        // FR-005 / SC-001: with the 2002 freq table, 수도 → 首都 (freq 136) leads 修道/水道/囚徒,
        // overriding the gloss-first/syllable-frequency heuristic. Source order is deliberately scrambled.
        let words = WordTable.parse("수도:水道:\n수도:修道:\n수도:首都:\n수도:囚徒:")
        let freq = FreqTable.parse("수도:首都:136\n수도:修道:7\n수도:水道:4\n수도:囚徒:1")
        let result = try makeConverter().candidates(forWord: "수도", using: words, freq: freq).map(\.value)
        XCTAssertEqual(result, ["首都", "修道", "水道", "囚徒"])
    }

    func testWordCandidatesFallBackToGlossOrderWithoutFreq() throws {
        // FR-005 / SC-002: a reading absent from the freq table keeps the exact 002 gloss-first order
        // (no regression) — candidates(forWord:using:freq:) == candidates(forWord:using:).
        let words = WordTable.parse("한국:寒國:\n한국:寒菊:\n한국:韓國:대한민국\n한국:汗國:")
        let conv = try makeConverter()
        let base = conv.candidates(forWord: "한국", using: words).map(\.value)
        let unrelatedFreq = FreqTable.parse("수도:首都:136")  // has no 한국 entry
        let withFreq = conv.candidates(forWord: "한국", using: words, freq: unrelatedFreq).map(\.value)
        XCTAssertEqual(withFreq, base)        // freq lacks 한국 → identical to 002
        XCTAssertEqual(base.first, "韓國")     // 002 gloss-first still holds
    }

    func testWordCandidatesFrequencyRankedLeadUnrankedTail() throws {
        // FR-006: the freq table reorders but never drops candidates — a Hanja with no corpus count
        // still appears, after the frequency-ranked ones.
        let words = WordTable.parse("수도:水道:\n수도:首都:\n수도:隧道:")  // 隧道 absent from freq
        let freq = FreqTable.parse("수도:首都:136\n수도:水道:4")
        let result = try makeConverter().candidates(forWord: "수도", using: words, freq: freq).map(\.value)
        XCTAssertEqual(result.count, 3)            // nothing dropped
        XCTAssertEqual(Array(result.prefix(2)), ["首都", "水道"])  // ranked ones first, by frequency
        XCTAssertEqual(result.last, "隧道")        // unranked sinks to the tail
    }

    // MARK: - 005 single-Hanja curation

    func testCurateGlossFirstThenEmptyThenVariant() {
        // spec 005 v1: clean gloss → empty gloss → variant-pointer, libhangul order within each tier;
        // never drops a candidate.
        let entries = [
            HanjaTable.Entry(hanja: "可", gloss: "옳을 가"),    // clean
            HanjaTable.Entry(hanja: "价", gloss: nil),          // empty
            HanjaTable.Entry(hanja: "仮", gloss: "假의 略字"),   // variant pointer
            HanjaTable.Entry(hanja: "家", gloss: "집 가"),       // clean
            HanjaTable.Entry(hanja: "椵", gloss: nil),          // empty
            HanjaTable.Entry(hanja: "謌", gloss: "歌와 同字"),   // variant pointer
        ]
        let got = Converter.curate(entries)
        XCTAssertEqual(got.map(\.hanja), ["可", "家", "价", "椵", "仮", "謌"])
        XCTAssertEqual(got.count, entries.count) // reordered, never dropped
    }

    func testSyllableCandidatesAreCurated() throws {
        // End-to-end through the bundled tables: a clean-gloss common char still leads, and any
        // variant-pointer char lands after the meaning-bearing ones.
        let result = try makeConverter().candidates(for: "가").map(\.value)
        XCTAssertEqual(result.first, "可")  // libhangul head, clean gloss → stays first
        if let kao = result.firstIndex(of: "仮") {  // 假의 略字 (variant) — demoted to the tail
            XCTAssertGreaterThan(kao, 20)
        }
    }
}
