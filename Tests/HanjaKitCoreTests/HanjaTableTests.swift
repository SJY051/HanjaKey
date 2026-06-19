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
}
