@testable import SFSafeSymbols
import XCTest

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
class RestrictionTests: XCTestCase {
    func testRestrictedSymbol() throws {
        // Test a known restricted symbol (FaceTime)
        let restrictedSymbol = SFSymbol.questionmarkVideoFill
        XCTAssertTrue(restrictedSymbol.isRestricted)
    }

    func testNonRestrictedSymbol() throws {
        // Test a non-restricted symbol
        let nonRestrictedSymbol = SFSymbol.heart
        XCTAssertFalse(nonRestrictedSymbol.isRestricted)
    }

    func testRestrictionsAreConsistentAcrossInstances() throws {
        let instance1 = SFSymbol.questionmarkVideoFill
        let instance2 = SFSymbol(rawValue: "questionmark.video.fill")
        XCTAssertEqual(instance1.isRestricted, instance2.isRestricted)
        XCTAssertTrue(instance1.isRestricted)
        XCTAssertTrue(instance2.isRestricted)
    }

    func testRestrictedSymbolFromRawValue() throws {
        let rawValue = "questionmark.video.fill"
        let symbol = SFSymbol(rawValue: rawValue)
        XCTAssertTrue(symbol.isRestricted)
    }

    func testAllRestrictionsDictionary() throws {
        // Verify the dictionary contains restricted symbols
        let restrictedSymbols = SFSymbol.allRestrictions.filter { $0.value }
        XCTAssertTrue(restrictedSymbols.count > 0, "Should have at least some restricted symbols")

        // Verify that questionmarkVideoFill is in the restrictions
        XCTAssertTrue(SFSymbol.allRestrictions[.questionmarkVideoFill] == true)
    }
}
