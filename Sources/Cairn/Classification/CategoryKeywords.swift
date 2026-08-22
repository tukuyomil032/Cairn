import Foundation

/// `Resources/CategoryKeywords.json`から読み込んだカテゴリ→キーワード辞書。
/// リビルドなしで手動メンテできるようキーワードをコードから外部化している。
struct CategoryKeywords: Sendable {
    let keywordsByCategory: [Category: [String]]

    static func loadBundled() -> CategoryKeywords {
        guard let url = Bundle.module.url(forResource: "CategoryKeywords", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("CategoryKeywords.json is missing from the bundle")
        }
        do {
            return try decode(data)
        } catch {
            fatalError("CategoryKeywords.json is malformed: \(error)")
        }
    }

    static func decode(_ data: Data) throws -> CategoryKeywords {
        let raw = try JSONDecoder().decode([String: [String]].self, from: data)
        var mapping: [Category: [String]] = [:]
        for (key, keywords) in raw {
            // 未知のキー（typo等）は無視する
            guard let category = Category(rawValue: key) else { continue }
            mapping[category] = keywords.map { $0.lowercased() }
        }
        return CategoryKeywords(keywordsByCategory: mapping)
    }
}
