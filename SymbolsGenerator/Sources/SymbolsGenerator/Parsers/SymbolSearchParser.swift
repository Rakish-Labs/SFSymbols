import Foundation

typealias SymbolSearchList = [String: Set<String>]

struct SymbolSearchParser {

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
                let keywords = try container.decode([String].self, forKey: key)
                symbols[key.stringValue] = keywords
            }

            self.symbols = symbols
        }
    }

    static func parse(searchFileData data: Data) throws -> SymbolSearchList? {
        let plist = try PropertyListDecoder().decode(Plist.self, from: data)

        var symbolSearchList: SymbolSearchList = [:]
        for (symbolName, keywords) in plist.symbols.sorted(using: KeyPathComparator(\.key)) {
            symbolSearchList[symbolName] = Set(keywords)
        }

        return symbolSearchList
    }
}
