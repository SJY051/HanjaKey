import XCTest

@testable import HanjaKitCore

final class TierTableTests: XCTestCase {
    func testParseRecordsPerReadingPositionInFileOrder() {
        let t = TierTable.parse("""
        # header comment
        가:家:0:집 가
        가:可:0:옳을 가
        가:歌:1:노래 가
        나:羅:0:벌일 라
        """)
        XCTAssertEqual(t.position(of: "家", for: "가"), 0)
        XCTAssertEqual(t.position(of: "可", for: "가"), 1)
        XCTAssertEqual(t.position(of: "歌", for: "가"), 2)
        XCTAssertEqual(t.position(of: "羅", for: "나"), 0)
    }

    func testHasReadingAndAbsentLookups() {
        let t = TierTable.parse("가:家:0:집 가\n")
        XCTAssertTrue(t.hasReading("가"))
        XCTAssertFalse(t.hasReading("나"))
        XCTAssertNil(t.position(of: "家", for: "나"))  // reading absent
        XCTAssertNil(t.position(of: "可", for: "가"))  // hanja absent within a known reading
    }

    func testParseSkipsBlankAndMalformedLines() {
        let t = TierTable.parse("\n가:家:0:집 가\n\nbadline\n가:可:1:옳을 가\n")
        XCTAssertEqual(t.position(of: "家", for: "가"), 0)
        XCTAssertEqual(t.position(of: "可", for: "가"), 1)  // malformed line didn't shift the index
    }

    func testFirstSeenWinsOnDuplicateHanja() {
        // The compile dedups, but be defensive: a repeated (reading, hanja) keeps its first position.
        let t = TierTable.parse("가:家:0:집 가\n가:可:0:옳을 가\n가:家:3:중복\n")
        XCTAssertEqual(t.position(of: "家", for: "가"), 0)
        XCTAssertEqual(t.position(of: "可", for: "가"), 1)
    }

    func testBundledLoadsTheShippedTable() {
        // The shipped tiers.txt must be present and cover a known ranked reading (家 = M2 rank 1 for 가).
        let t = TierTable.bundled()
        XCTAssertTrue(t.hasReading("가"))
        XCTAssertEqual(t.position(of: "家", for: "가"), 0)
    }
}
