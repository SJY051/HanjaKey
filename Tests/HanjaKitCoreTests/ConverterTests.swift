import XCTest
@testable import HanjaKitCore

final class ConverterTests: XCTestCase {
    private func makeConverter() throws -> Converter { try Converter.bundled() }

    // Sample fixture maps reading 한 → 漢 韓 恨.
    func testSyllableReturnsHanjaCandidates() throws {
        let result = try makeConverter().candidates(for: "한")
        XCTAssertTrue(result.contains { $0.value == "韓" && $0.kind == .hanja },
                      "expected 韓 among Hanja candidates for 한 — TODO: implement Converter/UnihanTable")
        XCTAssertTrue(result.contains { $0.value == "漢" })
    }

    func testJamoReturnsSymbolCandidates() throws {
        let result = try makeConverter().candidates(for: "ㅁ")
        XCTAssertFalse(result.isEmpty, "expected KS X 1001 symbols for ㅁ — TODO")
        XCTAssertTrue(result.allSatisfy { $0.kind == .symbol })
    }

    func testEmptyInputReturnsNoCandidates() throws {
        XCTAssertTrue(try makeConverter().candidates(for: "").isEmpty)
    }
}
