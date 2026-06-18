import XCTest
@testable import HanjaKitCore

final class HangulUtilTests: XCTestCase {
    func testSyllableDetected() {
        XCTAssertEqual(HangulUtil.classify("한"), .syllable("한"), "TODO: implement classify")
    }

    func testJamoDetected() {
        XCTAssertEqual(HangulUtil.classify("ㅁ"), .jamo("ㅁ"), "TODO: implement classify")
    }

    func testNonHangulIsOther() {
        XCTAssertEqual(HangulUtil.classify("A"), .other)
    }

    func testMultiCharIsOther() {
        XCTAssertEqual(HangulUtil.classify("한자"), .other)
    }
}
