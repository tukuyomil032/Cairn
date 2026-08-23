import Defaults

extension Defaults.Keys {
    /// 起動時の軽量トップカテゴリ更新（`CacheRefreshScheduler.refreshTopCategoryOnLaunch()`）に使う、
    /// 直近選択されたカテゴリ。書き込み側（カテゴリ選択時の更新）はPhase5のDiscovery UIで追加する。
    static let lastTopCategory = Key<Category?>("lastTopCategory")

    /// サイドバーが常時表示（ピン留め）されているか。次回起動時も保持する。
    /// デフォルトtrue: 初回起動時にナビゲーションが隠れているのは発見体験上悪いため。
    static let isSidebarPinned = Key<Bool>("isSidebarPinned", default: true)
}
