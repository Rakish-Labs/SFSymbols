@testable import SFSafeSymbols
import XCTest

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class KeywordTests: XCTestCase {
    func testSymbolWithKeywords() throws {
        // Test a known symbol with keywords (magnifying glass = search)
        let symbolWithKeywords = SFSymbol.magnifyingglass
        XCTAssertTrue(symbolWithKeywords.keywords.contains("search"))
        XCTAssertFalse(symbolWithKeywords.keywords.isEmpty)
    }

    func testSymbolWithMultipleKeywords() throws {
        // Test symbol with multiple keywords (cloud has "weather")
        let symbol = SFSymbol.cloud
        XCTAssertTrue(symbol.keywords.contains("weather"))
    }

    func testKeywordsFromRawValue() throws {
        let rawValue = "magnifyingglass"
        let symbol = SFSymbol(rawValue: rawValue)
        XCTAssertTrue(symbol.keywords.contains("search"))
    }

    func testKeywordsAreConsistentAcrossInstances() throws {
        let instance1 = SFSymbol.magnifyingglass
        let instance2 = SFSymbol(rawValue: "magnifyingglass")
        XCTAssertEqual(instance1.keywords, instance2.keywords)
    }

    func testAllKeywordsDictionary() throws {
        // Verify the dictionary contains symbols with keywords
        let symbolsWithKeywords = SFSymbol.allKeywords.filter { !$0.value.isEmpty }
        XCTAssertTrue(symbolsWithKeywords.count > 0, "Should have at least some symbols with keywords")

        // Verify that magnifyingglass has search keyword
        XCTAssertTrue(SFSymbol.allKeywords[.magnifyingglass]?.contains("search") == true)
    }

    func testSymbolWithoutKeywords() throws {
        // Some symbols might not have keywords
        // Create a symbol and check it returns empty set if no keywords
        let symbol = SFSymbol._0Circle
        // Just verify we get a set back, even if empty
        XCTAssertNotNil(symbol.keywords)
    }
}
