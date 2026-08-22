import Foundation

/// 分類結果。subTagsは分類先カテゴリに関わらず常に元のtopicsをそのまま併記する
/// （分類済みアプリでもtopicsベースの絞り込み・検索を可能にするための設計判断）。
struct ClassificationResult: Equatable, Sendable {
    let category: Category
    let subTags: [String]
}

/// リポジトリをCategoryへ分類するプロトコル。
/// 将来的にスコアリング方式を差し替えられるようStrategyパターン化する。
protocol CategoryClassifying: Sendable {
    func classify(repository: Repository, readme: String?) -> ClassificationResult
}

/// topics完全一致(3点) > リポジトリ名部分一致(2点) > README冒頭一致(1点)の
/// スコアリングで最高得点のカテゴリを採用する実装。全カテゴリ0点なら`.other`。
struct CategoryClassifier: CategoryClassifying {
    private let keywords: CategoryKeywords
    // README「冒頭」の範囲。数値指定の要件はないため、タイトル+概要段落程度を
    // カバーしつつ詳細セクションには踏み込まない目安として500文字を採用する。
    private static let readmePrefixLength = 500

    init(keywords: CategoryKeywords = .loadBundled()) {
        self.keywords = keywords
    }

    func classify(repository: Repository, readme: String?) -> ClassificationResult {
        let topics = Set(repository.topics.map { $0.lowercased() })
        let nameLowercased = repository.name.lowercased()
        let readmePrefix = readme.map { String($0.prefix(Self.readmePrefixLength)).lowercased() }

        var bestCategory: Category?
        var bestScore = 0

        // Category.allCasesの宣言順で走査する（Dictionaryのキー順は不定なため、
        // 同点タイブレークを決定的にするにはこの順序依存が必須）。
        for category in Category.allCases where category != .other {
            guard let categoryKeywords = keywords.keywordsByCategory[category] else { continue }
            var score = 0
            for keyword in categoryKeywords {
                if topics.contains(keyword) { score += 3 }
                if nameLowercased.contains(keyword) { score += 2 }
                if let readmePrefix, readmePrefix.contains(keyword) { score += 1 }
            }
            if score > bestScore {
                bestScore = score
                bestCategory = category
            }
        }

        return ClassificationResult(category: bestCategory ?? .other, subTags: repository.topics)
    }
}
