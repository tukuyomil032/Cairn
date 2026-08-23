extension Category {
    /// サイドバー・カード等での表示用日本語ラベル。
    var displayName: String {
        switch self {
        case .developerTools: return "開発者ツール"
        case .productivity: return "生産性"
        case .mediaCreation: return "メディア制作"
        case .music: return "音楽"
        case .photography: return "写真"
        case .utilities: return "ユーティリティ"
        case .system: return "システム"
        case .games: return "ゲーム"
        case .communication: return "コミュニケーション"
        case .education: return "教育"
        case .other: return "その他"
        }
    }

    /// サイドバーのカテゴリ行アイコン。`docs/design/iconography.md`のマッピング表は
    /// 全般的なUIロール（検索・すべてのアプリ・ライブラリ等）のみを定義しており、
    /// カテゴリ別アイコンは規定がないため、既存の実在するSF Symbol名から妥当なものを選定した。
    var sfSymbolName: String {
        switch self {
        case .developerTools: return "hammer"
        case .productivity: return "checklist"
        case .mediaCreation: return "paintbrush"
        case .music: return "music.note"
        case .photography: return "camera"
        case .utilities: return "wrench.and.screwdriver"
        case .system: return "gearshape.2"
        case .games: return "gamecontroller"
        case .communication: return "bubble.left.and.bubble.right"
        case .education: return "graduationcap"
        case .other: return "ellipsis.circle"
        }
    }
}
