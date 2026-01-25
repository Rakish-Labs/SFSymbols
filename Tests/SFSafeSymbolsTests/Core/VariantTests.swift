@testable import SFSafeSymbols
import XCTest

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class VariantTests: XCTestCase {
    func testBasicFillVariant() throws {
        let heartFill = SFSymbol.heartFill
        XCTAssertEqual(heartFill.baseSymbol, SFSymbol.heart)
        XCTAssertEqual(heartFill.variantType, "fill")
        XCTAssertTrue(heartFill.isVariant)
    }

    func testCircleVariant() throws {
        let heartCircle = SFSymbol.heartCircle
        XCTAssertEqual(heartCircle.baseSymbol, SFSymbol.heart)
        XCTAssertEqual(heartCircle.variantType, "circle")
        XCTAssertTrue(heartCircle.isVariant)
    }

    func testSlashVariant() throws {
        let bellSlash = SFSymbol.bellSlash
        XCTAssertEqual(bellSlash.baseSymbol, SFSymbol.bell)
        XCTAssertEqual(bellSlash.variantType, "slash")
        XCTAssertTrue(bellSlash.isVariant)
    }

    func testBadgeVariant() throws {
        let folderBadgePlus = SFSymbol.folderBadgePlus
        XCTAssertEqual(folderBadgePlus.baseSymbol, SFSymbol.folder)
        XCTAssertEqual(folderBadgePlus.variantType, "badge")
        XCTAssertTrue(folderBadgePlus.isVariant)
    }

    func testNestedVariant() throws {
        // heart.circle.fill is a fill variant of heart.circle, which is a circle variant of heart
        let heartCircleFill = SFSymbol.heartCircleFill
        XCTAssertEqual(heartCircleFill.baseSymbol, SFSymbol.heartCircle)
        XCTAssertEqual(heartCircleFill.variantType, "fill")
        XCTAssertTrue(heartCircleFill.isVariant)

        // heart.circle is a variant of heart
        let heartCircle = SFSymbol.heartCircle
        XCTAssertEqual(heartCircle.baseSymbol, SFSymbol.heart)
        XCTAssertEqual(heartCircle.variantType, "circle")
    }

    func testBaseSymbolHasNoBaseSymbol() throws {
        let heart = SFSymbol.heart
        XCTAssertNil(heart.baseSymbol)
        XCTAssertNil(heart.variantType)
        XCTAssertFalse(heart.isVariant)
    }

    func testVariantsProperty() throws {
        let heart = SFSymbol.heart
        let variants = heart.variants

        // heart should have direct variants like heart.fill, heart.circle, heart.slash, etc.
        XCTAssertTrue(variants.contains(SFSymbol.heartFill))
        XCTAssertTrue(variants.contains(SFSymbol.heartCircle))
        XCTAssertTrue(variants.contains(SFSymbol.heartSlash))

        // But not nested variants like heart.circle.fill
        XCTAssertFalse(variants.contains(SFSymbol.heartCircleFill))
    }

    func testDottedAmbiguityHandling() throws {
		// list.bullet.below.rectangle is not a variant (it's a base symbol with a simple name)
		let listBulletBelowRectangle = SFSymbol.listBulletBelowRectangle
		XCTAssertNil(listBulletBelowRectangle.baseSymbol)
		XCTAssertNil(listBulletBelowRectangle.variantType)
		XCTAssertFalse(listBulletBelowRectangle.isVariant)
		
		// But checkmark.rectangle IS a variant
		let checkmarkRectangle = SFSymbol.checkmarkRectangle
		XCTAssertEqual(checkmarkRectangle.baseSymbol, SFSymbol.checkmark)
		XCTAssertEqual(checkmarkRectangle.variantType, "rectangle")
		XCTAssertTrue(checkmarkRectangle.isVariant)
    }

    func testVariantsFromRawValue() throws {
        let heartFillFromStatic = SFSymbol.heartFill
        let heartFillFromRawValue = SFSymbol(rawValue: "heart.fill")
        XCTAssertEqual(heartFillFromStatic.baseSymbol, heartFillFromRawValue.baseSymbol)
        XCTAssertEqual(heartFillFromStatic.variantType, heartFillFromRawValue.variantType)
        XCTAssertEqual(heartFillFromStatic.isVariant, heartFillFromRawValue.isVariant)
    }

    func testInverseVariant() throws {
        let wandAndRaysInverse = SFSymbol.wandAndRaysInverse
        XCTAssertEqual(wandAndRaysInverse.baseSymbol, SFSymbol.wandAndRays)
        XCTAssertEqual(wandAndRaysInverse.variantType, "inverse")
        XCTAssertTrue(wandAndRaysInverse.isVariant)
    }

    func testSquareVariant() throws {
        let starSquare = SFSymbol.starSquare
        XCTAssertEqual(starSquare.baseSymbol, SFSymbol.star)
        XCTAssertEqual(starSquare.variantType, "square")
        XCTAssertTrue(starSquare.isVariant)
    }

    func testVariantsConsistentAcrossInstances() throws {
        let instance1 = SFSymbol.bellSlashFill
        let instance2 = SFSymbol(rawValue: "bell.slash.fill")
        XCTAssertEqual(instance1.baseSymbol, instance2.baseSymbol)
        XCTAssertEqual(instance1.variantType, instance2.variantType)
        XCTAssertEqual(instance1.isVariant, instance2.isVariant)
    }

    func testBaseSymbolsExcludesVariants() throws {
        let baseSymbols = SFSymbol.baseSymbols

        // Base symbols should include base symbols
        XCTAssertTrue(baseSymbols.contains(SFSymbol.heart))
        XCTAssertTrue(baseSymbols.contains(SFSymbol.bell))
        XCTAssertTrue(baseSymbols.contains(SFSymbol.star))

        // Base symbols should NOT include variant symbols
        XCTAssertFalse(baseSymbols.contains(SFSymbol.heartFill))
        XCTAssertFalse(baseSymbols.contains(SFSymbol.heartCircle))
        XCTAssertFalse(baseSymbols.contains(SFSymbol.bellSlash))
        XCTAssertFalse(baseSymbols.contains(SFSymbol.starSquare))

        // Base symbols should NOT include nested variants
        XCTAssertFalse(baseSymbols.contains(SFSymbol.heartCircleFill))
    }

    func testBaseSymbolsCountRelationship() throws {
        let allSymbols = SFSymbol.allSymbols
        let baseSymbols = SFSymbol.baseSymbols
        let variantSymbols = allSymbols.filter { $0.isVariant }

        // Base symbols + variant symbols should equal all symbols
        XCTAssertEqual(baseSymbols.count + variantSymbols.count, allSymbols.count)
    }

    func testBaseSymbolsAreAllNonVariants() throws {
        let baseSymbols = SFSymbol.baseSymbols

        // Every symbol in baseSymbols should have isVariant == false
        for symbol in baseSymbols {
            XCTAssertFalse(symbol.isVariant, "\(symbol.rawValue) should not be a variant")
            XCTAssertNil(symbol.baseSymbol, "\(symbol.rawValue) should have no base symbol")
            XCTAssertNil(symbol.variantType, "\(symbol.rawValue) should have no variant type")
        }
    }

    func testAllVariantsNotInBaseSymbols() throws {
        let baseSymbols = SFSymbol.baseSymbols

        // Check a sample of known variants to ensure they're not in baseSymbols
        let knownVariants: [SFSymbol] = [
            .heartFill, .heartCircle, .heartSlash,
            .bellSlash, .bellFill,
            .starFill, .starCircle, .starSquare,
            .wandAndRaysInverse
        ]

        for variant in knownVariants {
            XCTAssertFalse(baseSymbols.contains(variant), "\(variant.rawValue) should not be in baseSymbols")
        }
    }

    func testStackVariant() throws {
        let squareStack = SFSymbol.squareStack
        XCTAssertEqual(squareStack.baseSymbol, SFSymbol.square)
        XCTAssertEqual(squareStack.variantType, "stack")
        XCTAssertTrue(squareStack.isVariant)
    }
}
