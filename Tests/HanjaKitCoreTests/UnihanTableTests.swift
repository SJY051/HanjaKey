import XCTest
@testable import HanjaKitCore

final class UnihanTableTests: XCTestCase {
    // U+6F22 = 漢. The ":0E" source tag must be stripped, leaving reading 한.
    func testParseStripsSourceTagAndBuildsInverseMap() {
        let table = UnihanTable.parse("U+6F22\tkHangul\t한:0E")
        XCTAssertEqual(table.hanja(for: "한"), ["漢"], "TODO: implement parse")
    }

    func testMultipleCharsForSameReading() {
        let text = "U+6F22\tkHangul\t한:0E\nU+97D3\tkHangul\t한:0E" // 漢, 韓
        XCTAssertEqual(Set(UnihanTable.parse(text).hanja(for: "한")), Set(["漢", "韓"]))
    }

    func testCommentAndBlankLinesIgnored() {
        let text = "# comment\n\nU+5B57\tkHangul\t자:0E" // 字
        XCTAssertEqual(UnihanTable.parse(text).hanja(for: "자"), ["字"])
    }
}
