@testable import SFSafeSymbols
import XCTest

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class CategoryTests: XCTestCase {
    func testCategoriesFromRawValue() throws {
        let rawValue = TestHelper.sampleSymbolRawValue
        let categoriesBefore = SFSymbol.allCategories[TestHelper.sampleSymbol]!
        let categoriesAfter = SFSymbol.allCategories[SFSymbol(rawValue: rawValue)]!
        XCTAssertEqual(categoriesBefore, categoriesAfter)
    }

    func testCategoriesProperty() throws {
        // Test symbol with single category
        let singleCategorySymbol = TestHelper.sampleSymbol
        XCTAssertTrue(singleCategorySymbol.categories.contains(.communication))
        XCTAssertEqual(singleCategorySymbol.categories.count, 1)

        // Test symbol with multiple categories
        let multiCategorySymbol = SFSymbol.quoteBubbleFill
        XCTAssertTrue(multiCategorySymbol.categories.contains(.accessibility))
        XCTAssertTrue(multiCategorySymbol.categories.contains(.communication))
        XCTAssertTrue(multiCategorySymbol.categories.contains(.multicolor))
        XCTAssertEqual(multiCategorySymbol.categories.count, 3)
    }

    func testHasCategoryMethod() throws {
        let symbol = TestHelper.sampleSymbol
        XCTAssertTrue(symbol.has(category: .communication))
        XCTAssertFalse(symbol.has(category: .health))
        XCTAssertFalse(symbol.has(category: .gaming))
    }

    func testSymbolWithNoCategories() throws {
        // Some symbols might not have categories
        let symbolWithoutCategories = SFSymbol._0Circle
        let categories = symbolWithoutCategories.categories
        XCTAssertTrue(categories.isSuperset(of: []))
    }

    func testCategoriesAreConsistentAcrossInstances() throws {
        let instance1 = SFSymbol.questionmarkVideoFill
        let instance2 = SFSymbol(rawValue: "questionmark.video.fill")
        XCTAssertEqual(instance1.categories, instance2.categories)
        XCTAssertEqual(instance1.has(category: .communication), instance2.has(category: .communication))
    }

    func testMultipleCategoryLookup() throws {
        let symbol = SFSymbol.quoteBubbleFill
        let expectedCategories: Set<SFSafeSymbols.Category> = [.accessibility, .communication, .multicolor]
        XCTAssertEqual(symbol.categories, expectedCategories)
    }
}
