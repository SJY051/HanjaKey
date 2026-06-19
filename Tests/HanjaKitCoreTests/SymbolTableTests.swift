import XCTest
@testable import HanjaKitCore

final class SymbolTableTests: XCTestCase {
    func testParseMapDecodesJamoSymbolJSON() throws {
        let data = Data(#"{"ㅏ": ["←", "→"], "ㄱ": ["!"]}"#.utf8)
        let map = try SymbolTable.parseMap(data)
        XCTAssertEqual(map["ㅏ"], ["←", "→"])
        XCTAssertEqual(map["ㄱ"], ["!"])
    }

    func testMergingAddsOverridesAndKeeps() {
        let base = SymbolTable(jamoToSymbols: ["ㄱ": ["!"], "ㅁ": ["※"]])
        let merged = base.merging(["ㅏ": ["←", "→"], "ㄱ": ["@"], "ㅗ": []])
        XCTAssertEqual(merged.symbols(for: "ㅏ"), ["←", "→"]) // added to an empty jamo
        XCTAssertEqual(merged.symbols(for: "ㄱ"), ["@"])       // overridden
        XCTAssertEqual(merged.symbols(for: "ㅁ"), ["※"])       // untouched
        XCTAssertTrue(merged.symbols(for: "ㅗ").isEmpty)       // empty overlay ignored
    }
}
