import XCTest
@testable import HanjaKitCore

/// Spec 003-ranking-data, M1 — `FreqTable` parse/lookup. See docs/specs/003-ranking-data/spec.md.
final class FreqTableTests: XCTestCase {
    func testParseGroupsByReadingWithFrequencies() {
        // FR-004: `읽기:한자:빈도` → frequency(of:for:).
        let t = FreqTable.parse("수도:首都:136\n수도:水道:4")
        XCTAssertEqual(t.frequency(of: "首都", for: "수도"), 136)
        XCTAssertEqual(t.frequency(of: "水道", for: "수도"), 4)
    }

    func testUnknownReadingAndHanjaReturnNil() {
        // FR-007: unknown reading/hanja → nil; hasReading reflects presence.
        let t = FreqTable.parse("수도:首都:136")
        XCTAssertNil(t.frequency(of: "電氣", for: "전기"))
        XCTAssertNil(t.frequency(of: "水道", for: "수도"))
        XCTAssertFalse(t.hasReading("전기"))
        XCTAssertTrue(t.hasReading("수도"))
    }

    func testMalformedRowsSkippedDefensively() {
        // FR-004: blank / `#` / non-integer / short rows are skipped without crashing.
        let t = FreqTable.parse("# comment\n\n수도:首都:136\n수도:水道:NaN\nbad line\n전기:電氣:121")
        XCTAssertEqual(t.frequency(of: "首都", for: "수도"), 136)
        XCTAssertNil(t.frequency(of: "水道", for: "수도"))   // non-integer frequency dropped
        XCTAssertEqual(t.frequency(of: "電氣", for: "전기"), 121)
    }
}
