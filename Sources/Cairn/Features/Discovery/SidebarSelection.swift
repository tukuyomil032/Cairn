/// サイドバーの`List(selection:)`にバインドする選択状態。
///
/// `DiscoveryViewModel.selectedCategory: Category?`だけでは「すべてのアプリ」「個別カテゴリ」
/// 「ライブラリ」の3値を表現できない（`Category?`は「ライブラリ」状態を持てない）ため、
/// 橋渡し用にこのenumを用意する。
enum SidebarSelection: Hashable {
    case all
    case category(Category)
    case library

    /// `DiscoveryViewModel.selectedCategory`へ変換する。`.library`は具体的なカテゴリを
    /// 指さないため`nil`（＝すべて表示のまま）を返す——Phase8でライブラリ画面が
    /// 実装されるまでの暫定的な扱い。
    var category: Category? {
        switch self {
        case .all, .library: return nil
        case .category(let category): return category
        }
    }
}
