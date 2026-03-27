import Foundation

/// The base symbol when scanned from the manifest
struct ScannedSymbol: Hashable {
    var name: String
    var availability: Availability
}

/// The symbol data type containing all versions for one specific symbol
struct Symbol: Hashable {
    var name: String
    var restriction: String?
    var preview: String?
    var availability: Availability
    var isBaseLocalizationAvailable: Bool
    var availableLocalizations: [Availability: Set<Localization>]
    var availableLayersets: [Availability: Set<String>]
    var categories: Set<Category>
    var keywords: Set<String>
    var olderSymbol: ScannedSymbol?
    var newerSymbol: ScannedSymbol?

    var propertyName: String { name.toPropertyName }
}

struct Availability: Comparable, Equatable, Hashable {
    var iOS: VersionString
    var tvOS: VersionString
    var watchOS: VersionString
    var visionOS: VersionString
    private var _macOS: VersionString
    var year: String // E. g. "2020" or "2020.1"

    var isBase: Bool { version == "1.0" }
    var macOS: VersionString { _macOS.rawValue == "10.15" ? .init(rawValue: "11.0") : _macOS }

    var version: String {
        let ver = Decimal(string: "1.0")! + (Decimal(string: year)! - Decimal(string: "2019")!)
        return String(format: "%.1f", NSDecimalNumber(decimal: ver).doubleValue)
    }

    var versionUnderscored: String { version.replacingOccurrences(of: ".", with: "_") }

    static private(set) var base: Availability!

    /// Convert into an expression than can be used in code when prefixed with either `#` or `@`.
    var availableExpression: String {
        "available(iOS \(iOS), macOS \(macOS), tvOS \(tvOS), watchOS \(watchOS), visionOS \(visionOS), *)"
    }

    /// Convert into an expression than can be used in code when prefixed with either `#` or `@`.
    /// Availability specifications which are not strictly more restrictive than `Availability.base` are dropped.
    var availableExpressionWithoutRedundancyToBase: String {
        "available(" +
        (iOS > Availability.base.iOS ? "iOS \(iOS), " : "") +
        (macOS > Availability.base.macOS ? "macOS \(macOS), " : "") +
        (tvOS > Availability.base.tvOS ? "tvOS \(tvOS), " : "") +
        (watchOS > Availability.base.watchOS ? "watchOS \(watchOS), " : "") +
        (visionOS > Availability.base.visionOS ? "visionOS \(visionOS), " : "") +
        "*)"
    }

    init(iOS: String, macOS: String, tvOS: String, watchOS: String, visionOS: String, year: String) {
        self.iOS = .init(rawValue: iOS)
        self._macOS = .init(rawValue: macOS)
        self.tvOS = .init(rawValue: tvOS)
        self.watchOS = .init(rawValue: watchOS)
        self.visionOS = .init(rawValue: visionOS)
        self.year = year

        if isBase { Availability.base = self }
    }

    static func < (lhs: Availability, rhs: Availability) -> Bool {
        // The `orderedDescending` is intentional, because the availability is smaller when the year is higher
        return lhs.year.compare(rhs.year, options: .numeric) == .orderedDescending
    }

    static func > (lhs: Availability, rhs: Availability) -> Bool {
        return lhs.year.compare(rhs.year, options: .numeric) == .orderedAscending
    }

    static func == (lhs: Availability, rhs: Availability) -> Bool {
        return lhs.year == rhs.year
    }
}

/// A single layerset availability specification when scanned from the layerset plist
struct LayersetAvailability {
    var name: String
    var availability: Availability
}

struct VersionString: RawRepresentable, Comparable, Hashable, CustomStringConvertible {

    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String {
        return rawValue
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue.compare(rhs.rawValue, options: .numeric) == .orderedSame
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.rawValue.compare(rhs.rawValue, options: .numeric) == .orderedAscending
    }
}

enum Localization: String, Hashable, CaseIterable {
    case ar = "ar"
    case bn = "bn"
    case el = "el"
    case gu = "gu"
    case he = "he"
    case hi = "hi"
    case ja = "ja"
    case km = "km"
    case kn = "kn"
    case ko = "ko"
    case ml = "ml"
    case mni = "mni"
    case mr = "mr"
    case my = "my"
    case or = "or"
    case pa = "pa"
    case ru = "ru"
    case rtl = "rtl"
    case sat = "sat"
    case si = "si"
    case ta = "ta"
    case te = "te"
    case th = "th"
    case zh = "zh"

    var title: String {
        switch self {
            case .ar: return "Arabic"
            case .bn: return "Bengali"
            case .el: return "Greek"
            case .gu: return "Gujarati"
            case .he: return "Hebrew"
            case .hi: return "Hindi"
            case .ja: return "Japanese"
            case .km: return "Central Khmer"
            case .kn: return "Kannada"
            case .ko: return "Korean"
            case .ml: return "Malayalam"
            case .mni: return "Manipuri"
            case .mr: return "Maranthi"
            case .my: return "Burmese"
            case .or: return "Oriya"
            case .pa: return "Punjabi"
            case .ru: return "Russian"
            case .rtl: return "Right-to-Left"
            case .sat: return "Santali"
            case .si: return "Sinhala"
            case .ta: return "Tamil"
            case .te: return "Telugu"
            case .th: return "Thai"
            case .zh: return "Chinese"
        }
    }
    /// The name for a variable exposing this localization, e.g. "zhTraditional".
    var variableName: String {
        decapFirst(noDots(rawValue.capitalized))
    }

    /// The name for the SymbolLocalization struct exposing this localization for the base availability.
    /// E.g. "Ar".
    var baseStructName: String {
        noDots(rawValue.capitalized)
    }

    /// The name for the SymbolLocalization struct exposing this localization given a specific (or base) availability.
    /// E.g. "Ar_v2" or "Ar_v2_0".
    func structName(for availability: Availability) -> String {
        // Remove (possibly multiple) ".0"s from the ending
        var version = String(availability.version.reversed().drop(while: [".", "0"].contains).reversed())
        version = version.replacingOccurrences(of: ".", with: "_")
        let availabilitySuffix = availability.isBase ? "" : ("_v" + version)
        return baseStructName + availabilitySuffix
    }
}

private let noDots: (String) -> String = { $0.replacingOccurrences(of: ".", with: "") }
private let decapFirst: (String) -> String = { String($0.prefix(1)).lowercased() + String($0.dropFirst()) }

enum Category: String, Hashable, CaseIterable, Comparable {
    case accessibility
    case arrows
    case automotive
    case cameraandphotos
    case commerce
    case communication
    case connectivity
    case devices
    case editing
    case fitness
    case gaming
    case health
    case home
    case human
    case indices
    case keyboard
    case maps
    case math
    case media
    case multicolor
    case nature
    case objectsandtools
    case privacyandsecurity
    case shapes
    case textformatting
    case time
    case transportation
    case variable
    case weather
    case whatsnew

    var title: String {
        switch self {
            case .accessibility: return "Accessibility"
            case .arrows: return "Arrows"
            case .automotive: return "Automotive"
            case .cameraandphotos: return "Camera & Photos"
            case .commerce: return "Commerce"
            case .communication: return "Communication"
            case .connectivity: return "Connectivity"
            case .devices: return "Devices"
            case .editing: return "Editing"
            case .fitness: return "Fitness"
            case .gaming: return "Gaming"
            case .health: return "Health"
            case .home: return "Home"
            case .human: return "Human"
            case .indices: return "Indices"
            case .keyboard: return "Keyboard"
            case .maps: return "Maps"
            case .math: return "Math"
            case .media: return "Media"
            case .multicolor: return "Multicolor"
            case .nature: return "Nature"
            case .objectsandtools: return "Objects & Tools"
            case .privacyandsecurity: return "Privacy & Security"
            case .shapes: return "Shapes"
            case .textformatting: return "Text Formatting"
            case .time: return "Time"
            case .transportation: return "Transportation"
            case .variable: return "Variable"
            case .weather: return "Weather"
            case .whatsnew: return "What's New"
        }
    }

    var variableName: String {
        rawValue
    }

    static func < (lhs: Category, rhs: Category) -> Bool {
        return lhs.title < rhs.title
    }
}

enum VariantType: String, Hashable, CaseIterable {
    // Terminal variants (usually appear last in symbol names)
    case fill
    case inverse
    case filled

    // Shape container variants
    case circle
    case square
    case rectangle

    // Modification variants
    case slash
    case badge
    case stack

    // Style variants
    case dashed
    case dotted

    var title: String {
        switch self {
            case .fill: return "Fill"
            case .inverse: return "Inverse"
            case .filled: return "Filled"
            case .circle: return "Circle"
            case .square: return "Square"
            case .rectangle: return "Rectangle"
            case .slash: return "Slash"
            case .badge: return "Badge"
            case .stack: return "Stack"
            case .dashed: return "Dashed"
            case .dotted: return "Dotted"
        }
    }
}

struct VariantInfo: Hashable {
    var baseSymbolName: String
    var variantType: VariantType
    var variantSuffix: String
}
