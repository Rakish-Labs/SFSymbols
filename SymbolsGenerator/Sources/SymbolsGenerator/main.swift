import AppKit
import Foundation

try stringifyResources()

// MARK: - Step 1: READ INPUT FILES

var nameAliases = try SFFileManager
    .read(file: "name_aliases", withExtension: "strings")
    .parse(using: StringDictionaryFileParser.parse)
    .map({ (oldName: $0.key, newName: $0.value) })

let legacyAliases = try SFFileManager
    .read(file: "legacy_aliases", withExtension: "strings")
    .parse(using: StringDictionaryFileParser.parse)
    .map({ (legacyName: $0.key, releasedName: $0.value) })

var symbolRestrictions = try SFFileManager
    .read(file: "symbol_restrictions", withExtension: "strings")
    .parse(using: StringDictionaryFileParser.parse)

let missingSymbolRestrictions = try SFFileManager
    .read(file: "symbol_restrictions_missing", withExtension: "strings")
    .parse(using: StringDictionaryFileParser.parse)

let symbolNames = try SFFileManager
    .read(file: "symbol_names", withExtension: "txt")
    .parse(using: SymbolNamesFileParser.parse)

let symbolPreviews = try SFFileManager
    .read(file: "symbol_previews", withExtension: "txt")
    .parse(using: SymbolPreviewsFileParser.parse)

guard
    let symbolManifest = try SFFileManager
        .read(file: "name_availability", withExtension: "plist")
        .parse(using: SymbolManifestParser.parse),
    let layerSetAvailabilitiesList = try SFFileManager
        .read(file: "layerset_availability", withExtension: "plist")
        .parse(using: LayersetAvailabilityParser.parse),
    let symbolCategoriesList = try SFFileManager
        .read(file: "symbol_categories", withExtension: "plist")
        .parse(using: SymbolCategoriesParser.parse),
    let symbolSearchList = try SFFileManager
        .read(file: "symbol_search", withExtension: "plist")
        .parse(using: SymbolSearchParser.parse)
else {
    fatalError("Error reading input files")
}

guard CommandLine.argc > 1 else {
    fatalError("Invalid output Directory")
}
let outputDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)

// MARK: - Step 2: MERGE INTO SINGLE DATABASE

// Create symbol preview dictionary based on symbolNames and symbolPreviews
let symbolPreviewForName: [String: String] = Dictionary(uniqueKeysWithValues: zip(symbolNames, symbolPreviews))
var symbolsWherePreviewIsntAvailable: [String] = []

// Remove legacy symbols
nameAliases = nameAliases.filter { alias in !legacyAliases.contains { legacyAlias in legacyAlias.legacyName == alias.oldName } }

// Add missing restricted symbols
symbolRestrictions = symbolRestrictions.merging(missingSymbolRestrictions) { original, _ in
    print("Duplicate restricted symbol was found")
    return original
}

let versionsWithNoLayersetInfo: [String] = []

func allAliases(for symbolName: String, includeSelf: Bool = true) -> [ScannedSymbol] {
    var result: [String] = includeSelf ? [symbolName] : []
    let olderAliases = nameAliases.filter { $0.newName == symbolName }.map(\.oldName)
    if olderAliases.isNotEmpty {
        result += olderAliases
    } else if let newestAlias = nameAliases.first(where: { $0.oldName == symbolName })?.newName {
        result += nameAliases
            .filter { $0.newName == newestAlias && $0.oldName != symbolName }
            .map(\.oldName) + [newestAlias]
    }
    return result
        .compactMap { name in symbolManifest.first { $0.name == name } }
        .sorted(using: KeyPathComparator(\.availability, order: .reverse))
}

// Merge all versions of the same symbol into one type.
// This process takes care of merging multiple localized variants + renamed variants from previous versions
var symbols: [Symbol] = []
for scannedSymbol in symbolManifest {
    let localization = Localization.allCases.first { scannedSymbol.name.hasSuffix(".\($0.rawValue)") }
    let nameWithoutSuffix = scannedSymbol.name.replacingOccurrences(
        of: (localization?.rawValue).flatMap { ".\($0)" } ?? "",
        with: ""
    )

    var availableLayersets: [Availability: Set<String>] = [:]

    // Only lookup layerset availability for main name (without localization suffix)
    // Assuming it is equal across all localizations...
    for layersetAvailability in layerSetAvailabilitiesList[nameWithoutSuffix] ?? [] {
        availableLayersets[layersetAvailability.availability] =
            (availableLayersets[layersetAvailability.availability] ?? Set())
            .union([layersetAvailability.name])
    }

    let primaryName = nameAliases.first { $0.oldName == nameWithoutSuffix }?.newName ?? nameWithoutSuffix

    let otherAliases = allAliases(for: nameWithoutSuffix)
    let newerSymbol = otherAliases.filter { $0.availability < scannedSymbol.availability }.first
    let olderSymbol = otherAliases.filter { $0.availability > scannedSymbol.availability }.last

    let preview: String? = otherAliases.compactMap { symbolPreviewForName[$0.name] }.first

    if preview == nil {
        symbolsWherePreviewIsntAvailable.append(nameWithoutSuffix)
    }

    if let (index, existingSymbol) = (symbols.enumerated().first { $1.name == nameWithoutSuffix }) {
        // The symbol already exists -> Manage localizations

        var availableLocalizations = existingSymbol.availableLocalizations
        var existingLocalizations = existingSymbol.availableLocalizations[scannedSymbol.availability] ?? []

        if let localization = localization {
            existingLocalizations.insert(localization)
        }
        if existingLocalizations.isNotEmpty {
            availableLocalizations[scannedSymbol.availability] = existingLocalizations
        }

        // Remove old symbol & define new symbol
        symbols[index] = Symbol(
            name: nameWithoutSuffix,
            restriction: existingSymbol.restriction,
            preview: existingSymbol.preview ?? preview,
            availability: [existingSymbol.availability, scannedSymbol.availability].max()!,
            isBaseLocalizationAvailable: existingSymbol.isBaseLocalizationAvailable || localization == nil,
            availableLocalizations: availableLocalizations,
            availableLayersets: availableLayersets,
            categories: existingSymbol.categories,
            keywords: existingSymbol.keywords,
            olderSymbol: existingSymbol.olderSymbol,
            newerSymbol: existingSymbol.newerSymbol
        )
    } else {
        // The symbol doesn't exist yet
        let categoryStrings = symbolCategoriesList[nameWithoutSuffix] ?? []
        let categories = Set(categoryStrings.compactMap { Category(rawValue: $0) })
        let keywords = symbolSearchList[nameWithoutSuffix] ?? []

        symbols.append(
            .init(
                name: nameWithoutSuffix,
                restriction: symbolRestrictions[primaryName],
                preview: preview,
                availability: scannedSymbol.availability,
                isBaseLocalizationAvailable: localization == nil,
                availableLocalizations: localization.flatMap { [scannedSymbol.availability: [$0]] } ?? [:],
                availableLayersets: availableLayersets,
                categories: categories,
                keywords: keywords,
                olderSymbol: olderSymbol,
                newerSymbol: newerSymbol
            )
        )
    }
}

// This is to fix a rare bug that only localized variants of a symbol, but not the base variant is available
// (see https://github.com/SFSafeSymbols/SFSafeSymbols/issues/107)
symbols = symbols.filter { $0.isBaseLocalizationAvailable }
symbolsWherePreviewIsntAvailable = symbolsWherePreviewIsntAvailable.filter { name in symbols.contains { $0.name == name } }

func layersetsOfAllVersions(of symbol: Symbol) -> [Availability: Set<String>] {
    var toMerge: [Availability: Set<String>] = [:]
    if let newerSymbol = symbol.newerSymbol {
        toMerge = symbols.first { $0.name == newerSymbol.name }!.availableLayersets
    } else if let olderSymbol = symbol.olderSymbol {
        toMerge = symbols.first { $0.name == olderSymbol.name }!.availableLayersets
    }
    return symbol.availableLayersets.merging(toMerge) { $0.union($1) }
}

// MARK: - Step 3: CODE GENERATION

let symbolToCode: (Symbol) -> String = { symbol in
    let completeLayersets = layersetsOfAllVersions(of: symbol)
    let layersetCount = completeLayersets.values.joined().count + 1
    let localizationCount = symbol.availableLocalizations.values.joined().count + 1

    let layersetString: String? = {
        guard !versionsWithNoLayersetInfo.contains(symbol.availability.version) else {
            return nil
        }
        return layersetCount > 1 ? "\(layersetCount) Layersets" : "Single Layerset"
    }()

    // Generate summary for docs (preview + number of localizations, layersets + potential use restriction)
    var outputString = "\t/// " + (symbol.preview ?? "No preview available") + "\n"
    let supplementString = [
        localizationCount > 1 ? "\(localizationCount) Localizations" : "Single Localization",
        layersetString,
        symbol.restriction != nil ? "⚠️ Restricted" : nil
    ].compactMap { $0 }.joined(separator: ", ")
    if supplementString.isNotEmpty {
        outputString += "\t/// \(supplementString)\n"
    }

    // Generate localization docs
    if symbol.availableLocalizations.isNotEmpty { // Omit localization block if only the Latin localization is available
        // Use "Left-to-Right" name for the standard localization if "Right-To-Left" is the only other localization
        let standardLocalizationName = symbol.availableLocalizations.values.joined().contains(.rtl) ? "Left-to-Right" : "Latin"

        outputString += "\t///\n\t/// Localizations:\n\t/// - \(standardLocalizationName)\n"
        var handledLocalizations: Set<Localization> = .init()
        for (availability, localizations) in symbol.availableLocalizations.sorted(using: KeyPathComparator(\.key, order: .reverse)) {
            let newLocalizations = localizations.subtracting(handledLocalizations)
            if newLocalizations.isNotEmpty {
                handledLocalizations.formUnion(newLocalizations)
                let availabilityNotice: String = availability < symbol.availability ? " (iOS \(availability.iOS), macOS \(availability.macOS), tvOS \(availability.tvOS), watchOS \(availability.watchOS))" : ""
                for localization in Array(newLocalizations).sorted(using: KeyPathComparator(\.title)) {
                    outputString += "\t/// - \(localization.title)\(availabilityNotice)\n"
                }
            }
        }
    }

    if !versionsWithNoLayersetInfo.contains(symbol.availability.version){
        // Generate layerset availability docs based on the assumption that layersets don't get removed
        var handledLayersets: Set<String> = .init()
        outputString += "\t///\n\t/// Layersets:\n\t/// - Monochrome\n"
        for (availability, layersets) in completeLayersets.sorted(using: KeyPathComparator(\.key, order: .reverse)) {
            let newLayersets = layersets.subtracting(handledLayersets)
            if !newLayersets.isEmpty {
                handledLayersets.formUnion(newLayersets)
                let availabilityNotice: String = availability < symbol.availability ? " (iOS \(availability.iOS), macOS \(availability.macOS), tvOS \(availability.tvOS), watchOS \(availability.watchOS))" : ""
                for layerset in Array(newLayersets).sorted() {
                    outputString += "\t/// - \(layerset.capitalized)\(availabilityNotice)\n"
                }
            }
        }
    } else {
        outputString += "\t///\n\t/// Layerset information unavailable\n"
    }

    // Generate category docs
    if symbol.categories.isNotEmpty {
        outputString += "\t///\n\t/// Categories:\n"
        for category in symbol.categories.sorted() {
            outputString += "\t/// - \(category.title)\n"
        }
    }

    // Generate use restriction docs
    if let restrictionMessage = symbol.restriction {
        outputString += "\t///\n\t/// - Warning: ⚠️ \(restrictionMessage)\n"
    }

    // Generate availability / deprecation specifications
    if let newerSymbol = symbol.newerSymbol {
        let newerName = newerSymbol.name.toPropertyName
        outputString += "\t@available(iOS, introduced: \(symbol.availability.iOS), deprecated: \(newerSymbol.availability.iOS), renamed: \"\(newerName)\")\n"
        outputString += "\t@available(macOS, introduced: \(symbol.availability.macOS), deprecated: \(newerSymbol.availability.macOS), renamed: \"\(newerName)\")\n"
        outputString += "\t@available(tvOS, introduced: \(symbol.availability.tvOS), deprecated: \(newerSymbol.availability.tvOS), renamed: \"\(newerName)\")\n"
        outputString += "\t@available(watchOS, introduced: \(symbol.availability.watchOS), deprecated: \(newerSymbol.availability.watchOS), renamed: \"\(newerName)\")\n"
        outputString += "\t@available(visionOS, introduced: \(symbol.availability.visionOS), deprecated: \(newerSymbol.availability.visionOS), renamed: \"\(newerName)\")\n"
    }

    // Generate symbol
    // Reduce [A: Set<B>] -> [(A, B)] -> [String]
    let structNames = symbol.availableLocalizations.flatMap { availability, localizations in
        localizations.map {
            symbol.availability == availability ? $0.baseStructName : $0.structName(for: availability)
        }
    }.sorted()

    let nonVariadicClassName: (Int) -> String = {
        $0 == 0 ? "SFSymbol" : ("SymbolWith\($0)Localization" + (($0 > 1) ? "s" : ""))
    }
    let variadics = structNames.isNotEmpty ? "<\(structNames.joined(separator: ", "))>" : ""

    outputString += "\tstatic var \(symbol.propertyName): \(nonVariadicClassName(localizationCount-1))\(variadics) { .init(rawValue: \"\(symbol.name)\") }"

    return outputString
}

let localizationsGroupedByAvailability: [Availability: [Symbol: Set<Localization>]] = {
    var result: [Availability: [Symbol: Set<Localization>]] = [:]
    symbols.forEach { sym in
        result[sym.availability, default: [:]][sym] = []
        sym.availableLocalizations.forEach { ava, loc in
            var currentValue = result[ava] ?? [:]
            currentValue[sym, default: []].formUnion(loc)
            result[ava] = currentValue
        }
    }
    return result
}()

let baseAvailability = "@\(Availability.base.availableExpression)"

let symbolLocalizations: String = {
    let availabilities = Array(Set(symbols.map { $0.availability }))

    let usedCombinations: [(Localization, Availability)] = (Localization.allCases × availabilities).filter { loc, ava in
        ava.isBase || symbols.contains {
            $0.availability > ava && $0.availableLocalizations[ava]?.contains(loc) ?? false
        }
    }.sorted {
        let ((loc1, ava1), (loc2, ava2)) = ($0, $1)
        return loc1.structName(for: ava1) < loc2.structName(for: ava2)
    }

    let structDecl: (Localization, Availability) -> String = { loc, ava in
        var outputString = "\(baseAvailability)\n"
        outputString += "public struct \(loc.structName(for: ava)): SymbolLocalization {\n"
        outputString += "\tlet source: SFSymbol\n"
        outputString += "\tpublic init(source: SFSymbol) { self.source = source }\n"
        outputString += "\t@\(ava.availableExpression)\n"
        outputString += "\tpublic var \(loc.variableName): SFSymbol { .init(rawValue: \"\\(source.rawValue).\\(Localization.\(loc.variableName).rawValue)\") }\n"
        outputString += "}"
        return outputString
    }

    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"

    outputString += "public enum Localization: String, Equatable, Sendable {\n"
    outputString += Localization.allCases.map { "\tcase \($0.variableName) = \"\($0.rawValue)\""}.joined(separator: "\n")
    outputString += "\n}\n\n"

    outputString += "// MARK: - Static Localization\n\n"
    outputString += usedCombinations.map(structDecl).joined(separator: "\n\n")
    outputString += "\n"
    return outputString
}()

let groupedSymbols = Dictionary(grouping: symbols, by: \.availability)

let availabilityExtensions: [String] = groupedSymbols.map { availability, symbols in
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "// \(availability.version) Symbols\n"
    outputString += "@\(availability.availableExpression)\n"
    outputString += "public extension SFSymbol {\n"
    outputString += symbols.map(symbolToCode).joined(separator: "\n\n")
    outputString += "\n}\n"
    return outputString
}

let groupedAllLatestSymbolsFileContents: Dictionary<Availability, String> = localizationsGroupedByAvailability.reduce(into: [:]) {
    let (availability, symbolLocalizations) = $1
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "@\(availability.availableExpression)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static var localizationsAvailableSince\(availability.versionUnderscored): [SFSymbol : Set<Localization>] {\n"
    outputString += "\t\t["
    outputString += symbolLocalizations
        .sorted(using: KeyPathComparator(\.key.name))
        .map { sym, loc -> String in
            let locSet = "[" + loc.map { "." + $0.variableName }.sorted().joined(separator: ", ") + "]"
            return "\n\t\t\t" + sym.propertyName + ": " + locSet
        }.joined(separator: ",") + "\n"
    outputString += "\t\t]\n"
    outputString += "\t}\n"

    if !availability.isBase {
        outputString += "\n"
        let symbolsDeprecatedSinceThisAvailability = groupedSymbols[availability]!.compactMap(\.olderSymbol?.name).sorted()
        outputString += "\tinternal static var symbolsDeprecatedSince\(availability.versionUnderscored): Set<SFSymbol> {\n"
        outputString += "\t\t["
        outputString += symbolsDeprecatedSinceThisAvailability.map { "\n\t\t\t" + $0.toPropertyName }.joined(separator: ",")
        outputString += symbolsDeprecatedSinceThisAvailability.isNotEmpty ? "\n\t\t" : ""
        outputString += "]\n"
        outputString += "\t}\n"
    }

    outputString += "}\n"
    $0[availability] = outputString
}

// Group symbols by availability for categories (similar to localizations)
let categoriesGroupedByAvailability: [Availability: [Symbol: Set<Category>]] = {
    var result: [Availability: [Symbol: Set<Category>]] = [:]
    symbols.forEach { sym in
        if sym.categories.isNotEmpty {
            result[sym.availability, default: [:]][sym] = sym.categories
        }
    }
    return result
}()

let categoryEnumFileContents: String = {
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "public enum Category: String, Equatable, Sendable, CaseIterable {\n"
    outputString += Category.allCases.sorted().map { "\tcase \($0.variableName) = \"\($0.rawValue)\"" }.joined(separator: "\n")
    outputString += "\n}\n"
    return outputString
}()

let groupedAllCategoriesFileContents: Dictionary<Availability, String> = categoriesGroupedByAvailability.reduce(into: [:]) {
    let (availability, symbolCategories) = $1
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "@\(availability.availableExpression)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static var categoriesAvailableSince\(availability.versionUnderscored): [SFSymbol : Set<Category>] {\n"
    outputString += "\t\t["
    outputString += symbolCategories
        .sorted(using: KeyPathComparator(\.key.name))
        .map { sym, cat -> String in
            let catSet = "[" + cat.sorted().map { "." + $0.variableName }.joined(separator: ", ") + "]"
            return "\n\t\t\t" + sym.propertyName + ": " + catSet
        }.joined(separator: ",") + "\n"
    outputString += "\t\t]\n"
    outputString += "\t}\n"
    outputString += "}\n"
    $0[availability] = outputString
}

let allCategoriesExtension: String = {
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "\(baseAvailability)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static let allCategories: [SFSymbol : Set<Category>] = {\n"
    let availabilities = groupedSymbols.keys.sorted(using: ComparableComparator(order: .reverse)).dropFirst()
    outputString += "\t\tvar result = categoriesAvailableSince\(Availability.base.versionUnderscored)\n"
    outputString += "\t\t"
    outputString += availabilities.map { availability in
        var bodyString = "if #\(availability.availableExpressionWithoutRedundancyToBase) "
        bodyString += "{\n"
        bodyString += "\t\t\tresult.merge(categoriesAvailableSince\(availability.versionUnderscored)) { $0.union($1) }\n"
        return bodyString
    }.joined(separator: "\t\t}\n\t\t")
    outputString += "\t\t}\n"
    outputString += "\t\treturn result\n"
    outputString += "\t}()\n"
    outputString += "}\n"
    return outputString
}()

// Group symbols by availability for restrictions (similar to categories)
let restrictionsGroupedByAvailability: [Availability: [Symbol: Bool]] = {
    var result: [Availability: [Symbol: Bool]] = [:]
    symbols.forEach { sym in
        if sym.restriction != nil {
            result[sym.availability, default: [:]][sym] = true
        }
    }
    return result
}()

let groupedAllRestrictionsFileContents: Dictionary<Availability, String> = restrictionsGroupedByAvailability.reduce(into: [:]) {
    let (availability, symbolRestrictions) = $1
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "@\(availability.availableExpression)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static var restrictionsAvailableSince\(availability.versionUnderscored): [SFSymbol : Bool] {\n"
    outputString += "\t\t["
    outputString += symbolRestrictions
        .sorted(using: KeyPathComparator(\.key.name))
        .map { sym, _ -> String in
            return "\n\t\t\t" + sym.propertyName + ": true"
        }.joined(separator: ",") + "\n"
    outputString += "\t\t]\n"
    outputString += "\t}\n"
    outputString += "}\n"
    $0[availability] = outputString
}

let allRestrictionsExtension: String = {
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "\(baseAvailability)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static let allRestrictions: [SFSymbol : Bool] = {\n"
    // Only include availabilities that actually have restrictions
    let availabilities = restrictionsGroupedByAvailability.keys.sorted(using: ComparableComparator(order: .reverse)).dropFirst()
    outputString += "\t\tvar result = restrictionsAvailableSince\(Availability.base.versionUnderscored)\n"
    outputString += "\t\t"
    outputString += availabilities.map { availability in
        var bodyString = "if #\(availability.availableExpressionWithoutRedundancyToBase) "
        bodyString += "{\n"
        bodyString += "\t\t\tresult.merge(restrictionsAvailableSince\(availability.versionUnderscored)) { $0 || $1 }\n"
        return bodyString
    }.joined(separator: "\t\t}\n\t\t")
    outputString += "\t\t}\n"
    outputString += "\t\treturn result\n"
    outputString += "\t}()\n"
    outputString += "}\n"
    return outputString
}()

// Group symbols by availability for keywords (similar to categories)
let keywordsGroupedByAvailability: [Availability: [Symbol: Set<String>]] = {
    var result: [Availability: [Symbol: Set<String>]] = [:]
    symbols.forEach { sym in
        if sym.keywords.isNotEmpty {
            result[sym.availability, default: [:]][sym] = sym.keywords
        }
    }
    return result
}()

let groupedAllKeywordsFileContents: Dictionary<Availability, String> = keywordsGroupedByAvailability.reduce(into: [:]) {
    let (availability, symbolKeywords) = $1
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "@\(availability.availableExpression)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static var keywordsAvailableSince\(availability.versionUnderscored): [SFSymbol : Set<String>] {\n"
    outputString += "\t\t["
    outputString += symbolKeywords
        .sorted(using: KeyPathComparator(\.key.name))
        .map { sym, keywords -> String in
            let keywordSet = "[" + keywords.sorted().map { "\"\($0)\"" }.joined(separator: ", ") + "]"
            return "\n\t\t\t" + sym.propertyName + ": " + keywordSet
        }.joined(separator: ",") + "\n"
    outputString += "\t\t]\n"
    outputString += "\t}\n"
    outputString += "}\n"
    $0[availability] = outputString
}

let allKeywordsExtension: String = {
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "\(baseAvailability)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static let allKeywords: [SFSymbol : Set<String>] = {\n"
    // Only include availabilities that actually have keywords
    let availabilities = keywordsGroupedByAvailability.keys.sorted(using: ComparableComparator(order: .reverse)).dropFirst()
    outputString += "\t\tvar result = keywordsAvailableSince\(Availability.base.versionUnderscored)\n"
    outputString += "\t\t"
    outputString += availabilities.map { availability in
        var bodyString = "if #\(availability.availableExpressionWithoutRedundancyToBase) "
        bodyString += "{\n"
        bodyString += "\t\t\tresult.merge(keywordsAvailableSince\(availability.versionUnderscored)) { $0.union($1) }\n"
        return bodyString
    }.joined(separator: "\t\t}\n\t\t")
    outputString += "\t\t}\n"
    outputString += "\t\treturn result\n"
    outputString += "\t}()\n"
    outputString += "}\n"
    return outputString
}()

// MARK: - Variant Detection

let variantSuffixPatterns: [(pattern: String, type: VariantType, precedence: Int)] = [
    // Badge patterns (check compound suffixes first)
    ("badge.plus", .badge, 10),
    ("badge.minus", .badge, 10),
    ("badge.checkmark", .badge, 10),
    ("badge.xmark", .badge, 10),
    ("badge.exclamationmark", .badge, 10),
    ("badge.questionmark", .badge, 10),
    ("badge.ellipsis", .badge, 10),
    ("badge.person.crop", .badge, 10),
    ("badge.gearshape", .badge, 10),
    ("badge.gear", .badge, 10),
    ("badge.clock", .badge, 10),
    ("badge.arrow.up", .badge, 10),

    // Terminal variants (high precedence)
    ("fill", .fill, 5),
    ("inverse", .inverse, 5),
    ("filled", .filled, 5),

    // Shape variants (medium precedence)
    ("circle", .circle, 3),
    ("square", .square, 3),
    ("rectangle", .rectangle, 3),

    // Modifier variants (medium precedence)
    ("slash", .slash, 3),
    ("stack", .stack, 3),

    // Style variants (lower precedence - need existence check for ambiguous cases)
    ("dashed", .dashed, 2),
    ("dotted", .dotted, 2),
].sorted { $0.precedence > $1.precedence }

// Create lookup dictionaries for symbol names and availability
let symbolsByName: [String: Symbol] = Dictionary(uniqueKeysWithValues: symbols.map { ($0.name, $0) })

func detectVariant(
    for symbol: Symbol
) -> VariantInfo? {
    let symbolName = symbol.name
    let components = symbolName.split(separator: ".")

    for (pattern, type, _) in variantSuffixPatterns {
        let patternComponents = pattern.split(separator: ".")
        let patternCount = patternComponents.count

        // Check if symbol ends with this pattern
        guard components.count > patternCount else { continue }

        let suffixMatch = components.suffix(patternCount)
        let suffixStrings = suffixMatch.map { String($0) }
        let patternStrings = patternComponents.map { String($0) }
        guard suffixStrings == patternStrings else {
            continue
        }

        // Found potential match - check if base exists
        let baseName = components.dropLast(patternCount).joined(separator: ".")

        guard let baseSymbol = symbolsByName[baseName] else {
            continue
        }

        // IMPORTANT: Only treat as variant if base symbol has same or lower availability on ALL platforms
        // This prevents compilation errors where variants reference unavailable base symbols
        guard baseSymbol.availability.iOS <= symbol.availability.iOS &&
              baseSymbol.availability.macOS <= symbol.availability.macOS &&
              baseSymbol.availability.tvOS <= symbol.availability.tvOS &&
              baseSymbol.availability.watchOS <= symbol.availability.watchOS &&
              baseSymbol.availability.visionOS <= symbol.availability.visionOS else {
            continue
        }

        return VariantInfo(
            baseSymbolName: baseName,
            variantType: type,
            variantSuffix: pattern
        )
    }

    return nil
}

// Group symbols by availability for variants (similar to categories)
// IMPORTANT: Only include variants in availability groups where they're actually declared
let variantsGroupedByAvailability: [Availability: [Symbol: VariantInfo]] = {
    var result: [Availability: [Symbol: VariantInfo]] = [:]
    // Iterate over groupedSymbols to ensure we only include variants where they're declared
    for (availability, symbolsInGroup) in groupedSymbols {
        for sym in symbolsInGroup {
            if let variantInfo = detectVariant(for: sym) {
                result[availability, default: [:]][sym] = variantInfo
            }
        }
    }
    return result
}()

let groupedAllVariantsFileContents: Dictionary<Availability, String> = variantsGroupedByAvailability.reduce(into: [:]) {
    let (availability, symbolVariants) = $1
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "@\(availability.availableExpression)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static var variantsAvailableSince\(availability.versionUnderscored): [SFSymbol : (base: SFSymbol, type: String)] {\n"
    outputString += "\t\t["
    outputString += symbolVariants
        .sorted(using: KeyPathComparator(\.key.name))
        .map { sym, variantInfo -> String in
            return "\n\t\t\t" + sym.propertyName + ": (base: .\(variantInfo.baseSymbolName.toPropertyName), type: \"\(variantInfo.variantType.rawValue)\")"
        }.joined(separator: ",") + "\n"
    outputString += "\t\t]\n"
    outputString += "\t}\n"
    outputString += "}\n"
    $0[availability] = outputString
}

let allVariantsExtension: String = {
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "\(baseAvailability)\n"
    outputString += "extension SFSymbol {\n"
    outputString += "\tinternal static let allVariants: [SFSymbol : (base: SFSymbol, type: String)] = {\n"
    // Only include availabilities that actually have variants
    let availabilities = variantsGroupedByAvailability.keys.sorted(by: >).dropFirst()
    outputString += "\t\tvar result = variantsAvailableSince\(Availability.base.versionUnderscored)\n"
    outputString += "\t\t"
    outputString += availabilities.map { availability in
        var bodyString = "if #\(availability.availableExpressionWithoutRedundancyToBase) "
        bodyString += "{\n"
        bodyString += "\t\t\tresult.merge(variantsAvailableSince\(availability.versionUnderscored)) { _, new in new }\n"
        return bodyString
    }.joined(separator: "\t\t}\n\t\t")
    outputString += "\t\t}\n"
    outputString += "\t\treturn result\n"
    outputString += "\t}()\n"
    outputString += "}\n"
    return outputString
}()

let allSymbolsExtension: String = {
    var outputString = "// Don't touch this manually, this code is generated by the SymbolsGenerator helper tool\n\n"
    outputString += "\(baseAvailability)\n"
    outputString += "extension SFSymbol {\n"

    // `allCases` has been deprecated with the v3 release (spring of 2022)
    // It shall be removed entirely ~2 years after the v3 release
    outputString += "\t@available(*, deprecated, renamed: \"allSymbols\")\n"
    outputString += "\tpublic static var allCases: [SFSymbol] { Array(allSymbols) }\n\n"
    //

    outputString += "\tinternal static let allLocalizations: [SFSymbol : Set<Localization>] = {\n"
    let availabilities = groupedSymbols.keys.sorted(using: ComparableComparator(order: .reverse)).dropFirst()
    outputString += "\t\tvar result = localizationsAvailableSince\(Availability.base.versionUnderscored)\n"
    outputString += "\t\t"
    outputString += availabilities.map { availability in
        var bodyString = "if #\(availability.availableExpressionWithoutRedundancyToBase) "
        bodyString += "{\n"
        bodyString += "\t\t\tresult.merge(localizationsAvailableSince\(availability.versionUnderscored)) { $0.union($1) }\n"
        return bodyString
    }.joined(separator: "\t\t}\n\t\t")
    outputString += "\t\t}\n"
    outputString += "\t\treturn result\n"
    outputString += "\t}()\n"

    outputString += "\n"

    outputString += "\tpublic static let allSymbols: Set<SFSymbol> = {\n"
    outputString += "\t\tvar result = Set(allLocalizations.keys)\n"
    outputString += "\t\t"
    outputString += availabilities.map { availability in
        var bodyString = "if #\(availability.availableExpressionWithoutRedundancyToBase) "
        bodyString += "{\n"
        bodyString += "\t\t\tresult.subtract(symbolsDeprecatedSince\(availability.versionUnderscored))\n"
        return bodyString
    }.joined(separator: "\t\t}\n\t\t")
    outputString += "\t\t}\n"
    outputString += "\t\treturn result\n"
    outputString += "\t}()\n"
    outputString += "}\n"
    return outputString
}()

// MARK: - Step 4: OUTPUT

// Write availability extensions
try zip(groupedSymbols.keys, availabilityExtensions).forEach { availability, fileContents in
    let outputPath = outputDir.appending(path: "SFSymbol+\(availability.version).swift")
    try SFFileManager.write(fileContents, to: outputPath)
}

// Write AllSymbols extensions
try groupedAllLatestSymbolsFileContents.forEach { availability, fileContents in
    let outputPath = outputDir.appending(path: "SFSymbol+AllSymbols+\(availability.version).swift")
    try SFFileManager.write(fileContents, to: outputPath)
}

try SFFileManager.write(symbolLocalizations, to: outputDir.appending(path: "SymbolLocalizations.swift"))

// Write Category enum
try SFFileManager.write(categoryEnumFileContents, to: outputDir.appending(path: "SymbolCategory.swift"))

// Write per-availability category dictionaries
try groupedAllCategoriesFileContents.forEach { availability, fileContents in
    let outputPath = outputDir.appending(path: "SFSymbol+AllCategories+\(availability.version).swift")
    try SFFileManager.write(fileContents, to: outputPath)
}

// Write merged allCategories extension
try SFFileManager.write(allCategoriesExtension, to: outputDir.appending(path: "SFSymbol+AllCategories.swift"))

// Write per-availability restriction dictionaries
try groupedAllRestrictionsFileContents.forEach { availability, fileContents in
    let outputPath = outputDir.appending(path: "SFSymbol+AllRestrictions+\(availability.version).swift")
    try SFFileManager.write(fileContents, to: outputPath)
}

// Write merged allRestrictions extension
try SFFileManager.write(allRestrictionsExtension, to: outputDir.appending(path: "SFSymbol+AllRestrictions.swift"))

// Write per-availability keyword dictionaries
try groupedAllKeywordsFileContents.forEach { availability, fileContents in
    let outputPath = outputDir.appending(path: "SFSymbol+AllKeywords+\(availability.version).swift")
    try SFFileManager.write(fileContents, to: outputPath)
}

// Write merged allKeywords extension
try SFFileManager.write(allKeywordsExtension, to: outputDir.appending(path: "SFSymbol+AllKeywords.swift"))

// Write per-availability variant dictionaries
try groupedAllVariantsFileContents.forEach { availability, fileContents in
    let outputPath = outputDir.appending(path: "SFSymbol+AllVariants+\(availability.version).swift")
    try SFFileManager.write(fileContents, to: outputPath)
}

// Write merged allVariants extension
try SFFileManager.write(allVariantsExtension, to: outputDir.appending(path: "SFSymbol+AllVariants.swift"))

try SFFileManager.write(allSymbolsExtension, to: outputDir.appending(path: "SFSymbol+AllSymbols.swift"))

// MARK: - Step 5: FINISHING

if symbolsWherePreviewIsntAvailable.isNotEmpty {
    print("⚠️ No symbol preview available for symbols \(symbolsWherePreviewIsntAvailable)", to: &stderr)
}
