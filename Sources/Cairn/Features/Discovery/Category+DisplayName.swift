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
}
