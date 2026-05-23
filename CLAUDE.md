# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SFSymbols is a Swift library providing type-safe access to Apple's SF Symbols. Instead of using error-prone string literals like `UIImage(systemName: "circle.fill")`, developers use type-safe API: `UIImage(systemSymbol: .circleFill)`.

## Fork & Upstream Strategy

This is a rebrand fork of [SFSafeSymbols](https://github.com/SFSafeSymbols/SFSafeSymbols) (the `upstream` remote). The guiding goal is to **minimize divergence so upstream updates merge cleanly**.

- **Rebrand via path overrides, not directory moves.** The product and module are named `SFSymbols`, but sources stay at `Sources/SFSafeSymbols/` and `Tests/SFSafeSymbolsTests/`; `Package.swift` remaps them with `path:`. Never rename or move these directories — doing so makes every upstream change conflict.
- **Keep changes additive and out of upstream-owned files.** Generated symbol files are regenerated via `make`, never hand-edited or merged. Prefer new files/extensions over edits to existing upstream files.
- **Update by rebasing this thin patch series onto upstream, then regenerating** — not by merging upstream into a modified tree.
- `archive/fork-original` preserves the pre-rebrand fork history. Features still to port (categories, restrictions, keywords, variants) are specced in `features.md`.

## Build and Test

```bash
# Build library
swift build

# Run tests
swift test

# Run a single test
swift test --filter SFSymbolsTests.LocalizationTests

# Regenerate symbol definitions (dev mode; see Makefile for release/fork modes)
make
```

## Architecture

**Two distinct components:**

1. **Main Library** (directory `Sources/SFSafeSymbols/`, module `SFSymbols`) - The Swift package users import
   - `Symbols/SFSymbol.swift` - Core class with dynamic features (e.g. localization)
   - `Symbols/SFSymbol+*.swift` - Generated files containing symbol definitions per SF Symbols version
   - `Initializers/` - Extensions for SwiftUI, UIKit, and AppKit integration

2. **Code Generator** (`SymbolsGenerator/`) - Standalone macOS tool that generates symbol definitions
   - Reads Apple metadata files from `Resources/` (plist files, symbol names)
   - Outputs Swift files to `Sources/SFSafeSymbols/Symbols/`
   - Run via `make`

## Updating for New SF Symbols Versions

See `CONTRIBUTING.md` for detailed steps. Key files to update in `SymbolsGenerator/Sources/SymbolsGenerator/Resources/`:

- `symbol_names.txt` - Symbol names from SF Symbols app (Copy Names)
- `symbol_previews.txt` - Symbol previews from SF Symbols app (Copy Symbols)
- `name_availability.plist` - From CoreGlyphs.bundle or Xcode
- `layerset_availability.plist` - From SF Symbols.app metadata

After updating resources, regenerate: `make` (dev) or `make release [tag]`.

## Key Patterns

- Symbol names use lowerCamelCase with leading numbers prefixed by underscore: `circle.fill` → `circleFill`, `11.circle` → `_11Circle`
- Each symbol has `@available` attributes matching Apple's availability data
- Renamed symbols use deprecation notices pointing to the new name
