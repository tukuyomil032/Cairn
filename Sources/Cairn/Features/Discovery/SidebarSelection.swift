/// サイドバーの`List(selection:)`にバインドする選択状態。
///
/// `DiscoveryViewModel.selectedCategory: Category?`だけでは「すべてのアプリ」「個別カテゴリ」
/// 「ライブラリ」の3値を表現できない（`Category?`は「ライブラリ」状態を持てない）ため、
/// 橋渡し用にこのenumを用意する。
enum SidebarSelection: Hashable {
    case all
    case trending
    case category(Category)
    case library

    /// `DiscoveryViewModel.selectedCategory`へ変換する。`.trending`/`.library`は具体的な
    /// カテゴリを指さないため`nil`を返す——`.trending`は`TrendingViewModel.results`を、
    /// `.library`はPhase8実装までの暫定表示を、それぞれ別経路で表示する。
    var category: Category? {
        switch self {
        case .all, .trending, .library: return nil
        case .category(let category): return category
        }
    }
}
