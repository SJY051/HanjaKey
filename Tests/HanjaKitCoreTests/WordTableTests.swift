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
}
