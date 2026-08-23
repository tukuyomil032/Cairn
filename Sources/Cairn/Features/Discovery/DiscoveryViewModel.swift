import Defaults
import Foundation
import Observation
import SwiftData

/// Discovery画面の状態。SwiftDataキャッシュ済みの`CachedRepository`からの読み出し・
/// カテゴリフィルタ・件数集計のみを責務とする（API通信は行わない）。
///
/// API即応検索は既存の`SearchViewModel`が別途担当するため、責務が重複しないよう
/// このViewModelは「キャッシュ済みデータをカテゴリで絞り込んで表示する」役割に限定する。
@Observable
@MainActor
final class DiscoveryViewModel {
    /// 選択中のカテゴリ。`nil`は「すべてのアプリ」を意味する。
    var selectedCategory: Category? {
        didSet {
            guard selectedCategory != oldValue else { return }
            reload()
            // 「すべて」選択(nil)時はDefaultsを書き換えない。lastTopCategoryは起動時の
            // 軽量キャッシュ更新先ヒントであり、直前に見ていた具体カテゴリの情報を
            // 保持し続ける方がプリフェッチとして有意義なため（ユーザー確認済み）。
            if let selectedCategory {
                Defaults[.lastTopCategory] = selectedCategory
            }
        }
    }

    private(set) var repositoriesByCategory: [CachedRepository] = []
    private(set) var categoryCounts: [Category: Int] = [:]

    private let modelContext: ModelContext

    init(modelContext: ModelContext, initialCategory: Category? = Defaults[.lastTopCategory]) {
        self.modelContext = modelContext
        self.selectedCategory = initialCategory
        reload()
    }

    /// SwiftDataキャッシュから再読み込みし、`repositoriesByCategory`と`categoryCounts`を更新する。
    func reload() {
        let allRepositories = (try? modelContext.fetch(FetchDescriptor<CachedRepository>())) ?? []

        var counts: [Category: Int] = [:]
        for repository in allRepositories {
            guard let category = Category(rawValue: repository.category) else { continue }
            counts[category, default: 0] += 1
        }
        categoryCounts = counts

        if let selectedCategory {
            repositoriesByCategory = allRepositories.filter { $0.category == selectedCategory.rawValue }
        } else {
            repositoriesByCategory = allRepositories
        }
    }
}
