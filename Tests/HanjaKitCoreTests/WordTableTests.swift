import XCTest
@testable import HanjaKitCore

final class WordTableTests: XCTestCase {
    func testParseGroupsByReading() {
        let table = WordTable.parse("한자:漢字:\n한자:漢子:\n학교:學校:")
        XCTAssertEqual(table.entries(for: "한자").map(\.hanja), ["漢字", "漢子"])
        XCTAssertEqual(table.entries(for: "학교").map(\.hanja), ["學校"])
        XCTAssertTrue(table.entries(for: "없는말").isEmpty)
    }

    func testParsePreservesSourceOrder() {
        // WordTable no longer reorders; ranking is Converter's job now.
        let table = WordTable.parse("한국:寒國:\n한국:韓國:대한민국\n한국:汗國:")
        XCTAssertEqual(table.entries(for: "한국").map(\.hanja), ["寒國", "韓國", "汗國"])
    }

    func testMergingOverlaysGlossAndAddsEntries() {
        // 003 M2: the stdict overlay fills a missing gloss on a shared (reading,hanja), appends a new
        // hanja for an existing reading, and adds a new reading — all without duplicating.
        let lib = WordTable.parse("한국:韓國:\n한국:寒國:")  // 韓國 has no gloss yet
        let aug = WordTable.parse("한국:韓國:대한민국\n한국:汗國:오랑캐 나라\n가각:街角:거리 모서리")
        let merged = lib.merging(aug)
        let han = merged.entries(for: "한국")
        XCTAssertEqual(han.count, 3) // 韓國, 寒國 (existing) + 汗國 (new) — no duplicate of 韓國
        XCTAssertEqual(han.first { $0.hanja == "韓國" }?.gloss, "대한민국")     // gloss filled in
        XCTAssertEqual(han.first { $0.hanja == "汗國" }?.gloss, "오랑캐 나라")  // new hanja appended
        XCTAssertEqual(merged.entries(for: "가각").first?.hanja, "街角")        // new reading added
    }
}
