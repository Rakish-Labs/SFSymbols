@testable import SFSymbols

#if os(macOS)

    import XCTest

    class NSImageExtensionTests: XCTestCase {
        /// Tests, whether the `NSImage` retrieved via SFSymbols can be retrieved without a crash
        func testInit() {
            if #available(macOS 11.0, *) {
                for symbol in TestHelper.allSymbolsWithVariants {
                    print("Testing validity of \"\(symbol.rawValue)\" via NSImage init")

                    // If this doesn't crash, everything works fine
                    _ = NSImage(systemSymbol: symbol)
                }
            } else {
                XCTFail("macOS 11 is required to test SFSymbols.")
            }
        }
    }

#endif
