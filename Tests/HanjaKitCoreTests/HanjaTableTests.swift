import XCTest
@testable import HanjaKitCore

final class HanjaTableTests: XCTestCase {
    func testParsePreservesOrderAndGloss() {
        let table = HanjaTable.parse("한:韓:나라 이름 한\n한:漢:한수 한")
        let entries = table.entries(for: "한")
        XCTAssertEqual(entries.map(\.hanja), ["韓", "漢"], "frequency order must be preserved")
        XCTAssertEqual(entries.first?.gloss, "나라 이름 한")
    }

    func testEmptyGlossBecomesNil() {
        let table = HanjaTable.parse("각:斠:")
        XCTAssertEqual(table.entries(for: "각"), [HanjaTable.Entry(hanja: "斠", gloss: nil)])
    }

    func testCommentAndBlankLinesIgnored() {
        let table = HanjaTable.parse("# comment\n\n자:字:글자 자")
        XCTAssertEqual(table.entries(for: "자").map(\.hanja), ["字"])
    }

    func testUnknownReadingIsEmpty() {
        XCTAssertTrue(HanjaTable.parse("한:韓:나라 이름 한").entries(for: "없").isEmpty)
    }

    func testRankReflectsTableOrder() {
        let table = HanjaTable.parse("한:韓:나라 한\n한:漢:한수 한")
        XCTAssertEqual(table.rank(of: "韓", for: "한"), 0)
        XCTAssertEqual(table.rank(of: "漢", for: "한"), 1)
        XCTAssertNil(table.rank(of: "寒", for: "한"))
    }

    func testMergingFillsEmptyGlossOnly() {
        // Spec 004: the gloss overlay fills a nil gloss on an existing (reading, hanja), never overrides
        // a non-nil gloss, keeps the order, and ignores pairs absent from the base (no new candidates).
        let base = HanjaTable.parse("가:可:옳을 가\n가:椵:\n가:價:값 가") // 椵 has no gloss
        let overlay = HanjaTable.parse("가:椵:나무 이름 가\n가:可:DIFFERENT\n가:佳:아름다울 가\n나:奈:어찌 나")
        let merged = base.merging(overlay)
        let entries = merged.entries(for: "가")
        XCTAssertEqual(entries.map(\.hanja), ["可", "椵", "價"], "order + inventory unchanged (no 佳 added)")
        XCTAssertEqual(entries.first { $0.hanja == "椵" }?.gloss, "나무 이름 가", "empty gloss filled")
        XCTAssertEqual(entries.first { $0.hanja == "可" }?.gloss, "옳을 가", "non-nil gloss not overridden")
        XCTAssertTrue(merged.entries(for: "나").isEmpty, "overlay-only reading not added")
    }

    func testBundledOverlayFillsRareGloss() throws {
        // End-to-end: the bundled overlays load and fill a gloss libhangul left empty (spec 004).
        let table = try HanjaTable.bundled()
        XCTAssertNotNil(
            table.entries(for: "가").first { $0.hanja == "椵" }?.gloss,
            "椵 (가) is empty in libhangul; a bundled overlay should fill it"
        )
    }
}
