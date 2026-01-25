# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SFSafeSymbols is a Swift library providing type-safe access to Apple's SF Symbols. Instead of using error-prone string literals like `UIImage(systemName: "circle.fill")`, developers use type-safe API: `UIImage(systemSymbol: .circleFill)`.

## Build and Test

```bash
# Build library
swift build

# Run tests
swift test

# Run a single test
swift test --filter SFSafeSymbolsTests.LocalizationTests

# Regenerate symbol definitions from SF Symbols metadata
make generate-symbol
```

## Architecture

**Two distinct components:**

1. **Main Library** (`Sources/SFSafeSymbols/`) - The Swift package users import
   - `Symbols/SFSymbol.swift` - Core class with dynamic features (localization, categories, variants)
   - `Symbols/SFSymbol+*.swift` - Generated files containing symbol definitions per SF Symbols version
   - `Initializers/` - Extensions for SwiftUI, UIKit, and AppKit integration

2. **Code Generator** (`SymbolsGenerator/`) - Standalone macOS tool that generates symbol definitions
   - Reads Apple metadata files from `Resources/` (plist files, symbol names)
   - Outputs Swift files to `Sources/SFSafeSymbols/Symbols/`
   - Run via `make generate-symbol`

## Updating for New SF Symbols Versions

See `CONTRIBUTING.md` for detailed steps. Key files to update in `SymbolsGenerator/Sources/SymbolsGenerator/Resources/`:

- `symbol_names.txt` - Symbol names from SF Symbols app (Copy Names)
- `symbol_previews.txt` - Symbol previews from SF Symbols app (Copy Symbols)
- `name_availability.plist` - From CoreGlyphs.bundle or Xcode
- `layerset_availability.plist` - From SF Symbols.app metadata
- `symbol_categories.plist`, `symbol_search.plist` - Category and keyword data

After updating resources: `make generate-symbol`

## Key Patterns

- Symbol names use lowerCamelCase with leading numbers prefixed by underscore: `circle.fill` → `circleFill`, `11.circle` → `_11Circle`
- Each symbol has `@available` attributes matching Apple's availability data
- Renamed symbols use deprecation notices pointing to the new name
