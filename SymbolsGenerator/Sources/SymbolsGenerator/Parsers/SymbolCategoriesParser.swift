import Foundation

typealias SymbolCategoriesList = [String: Set<String>]

struct SymbolCategoriesParser {
    private struct Plist: Decodable {
        var symbols: [String: [String]]

        private struct DynamicCodingKeys: CodingKey {
            var stringValue: String
            init?(stringValue: String) {
                self.stringValue = stringValue
            }

            var intValue: Int?
            init?(intValue: Int) {
                return nil
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
            var symbols: [String: [String]] = [:]

            for key in container.allKeys {
                let categories = try container.decode([String].self, forKey: key)
                symbols[key.stringValue] = categories
            }

            self.symbols = symbols
        }
    }

    static func parse(categoriesFileData: Data) throws -> SymbolCategoriesList? {
        let data = categoriesFileData
        let plist = try PropertyListDecoder().decode(Plist.self, from: data)

        var symbolCategoriesList: SymbolCategoriesList = [:]

        for (symbolName, categories) in plist.symbols.sorted(using: KeyPathComparator(\.key)) {
            symbolCategoriesList[symbolName] = Set(categories)
        }

        return symbolCategoriesList
    }
}
