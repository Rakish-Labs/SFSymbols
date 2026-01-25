// Sendable is unchecked, but it's easy to assume it's safe:
// - Classes cannot be overriden outside of SFSafeSymbols, since they are public, not open
// - The only stored property is rawValue, and is immutable (let)
// See https://developer.apple.com/documentation/swift/sendable#Sendable-Classes

@available(iOS 13.0, macOS 11.0, tvOS 13.0, watchOS 6.0, visionOS 1.0, *)
public class SFSymbol: RawRepresentable, Equatable, Hashable, Codable, @unchecked Sendable {
    public let rawValue: String

    required public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: Dynamic Localization

    /// Determine whether `self` can be localized to `localization` on the current platform.
    public func has(localization: Localization) -> Bool {
        Self.allLocalizations[self]?.contains(localization) ?? false
    }

    /// If `self` is localizable to `localization`, localize it, otherwise return `nil`.
    public func localized(to localization: Localization) -> SFSymbol? {
        if has(localization: localization) {
            return SFSymbol(rawValue: "\(rawValue).\(localization.rawValue)")
        } else {
            return nil
        }
    }

    // MARK: Categories

    /// The set of categories this symbol belongs to.
    public var categories: Set<Category> {
        Self.allCategories[self] ?? []
    }

    /// Determine whether `self` belongs to `category`.
    public func has(category: Category) -> Bool {
        categories.contains(category)
    }

    // MARK: Restrictions

    /// Whether this symbol has usage restrictions.
    ///
    /// Restricted symbols may not be modified and may only be used to refer to specific Apple products or features.
    /// Check the symbol's documentation for the specific restriction message.
    public var isRestricted: Bool {
        Self.allRestrictions[self] ?? false
    }

    // MARK: Keywords

    /// The set of search keywords associated with this symbol.
    ///
    /// These keywords help identify symbols based on their meaning or use case.
    public var keywords: Set<String> {
        Self.allKeywords[self] ?? []
    }

    // MARK: Variants

    /// The base symbol if this symbol is a variant, or `nil` if this is a base symbol.
    ///
    /// For example, `heartFill.baseSymbol` returns `.heart`.
    public var baseSymbol: SFSymbol? {
        Self.allVariants[self]?.base
    }

    /// The variant type if this symbol is a variant, or `nil` if this is a base symbol.
    ///
    /// For example, `heartFill.variantType` returns `"fill"`.
    public var variantType: String? {
        Self.allVariants[self]?.type
    }

    /// Whether this symbol is a variant of another symbol.
    ///
    /// Returns `true` if this symbol has a base symbol, `false` otherwise.
    public var isVariant: Bool {
        Self.allVariants[self] != nil
    }

    /// All direct variants of this symbol.
    ///
    /// Returns an array of symbols that are variants of this symbol.
    /// For example, `heart.variants` includes `heartFill`, `heartCircle`, etc.,
    /// but not nested variants like `heartCircleFill`.
    public var variants: [SFSymbol] {
        Self.allVariants.compactMap { symbol, info in
            info.base == self ? symbol : nil
        }
    }

    /// All base (non-variant) symbols.
    ///
    /// Returns a set of symbols that are not variants of other symbols.
    /// For example, includes `heart` but excludes `heartFill` and `heartCircle`.
    public static var baseSymbols: Set<SFSymbol> {
        allSymbols.filter { !$0.isVariant }
    }
}
