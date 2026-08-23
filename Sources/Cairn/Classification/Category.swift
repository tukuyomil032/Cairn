import Defaults

/// アプリのジャンル分類。rawValueは`Resources/CategoryKeywords.json`のキーと一致させる。
/// 表示用の日本語ラベルはUI層（Phase5）で追加するためここでは持たせない。
enum Category: String, Codable, CaseIterable, Sendable, Defaults.Serializable {
    case developerTools
    case productivity
    case mediaCreation
    case music
    case photography
    case utilities
    case system
    case games
    case communication
    case education
    case other
}
