import Defaults

extension Defaults.Keys {
    /// 起動時の軽量トップカテゴリ更新（`CacheRefreshScheduler.refreshTopCategoryOnLaunch()`）に使う、
    /// 直近選択されたカテゴリ。書き込み側（カテゴリ選択時の更新）はPhase5のDiscovery UIで追加する。
    static let lastTopCategory = Key<Category?>("lastTopCategory")
}
