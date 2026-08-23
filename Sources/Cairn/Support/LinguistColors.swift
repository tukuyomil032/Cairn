import Foundation
import SwiftUI

/// `Resources/LinguistColors.json`から読み込んだ言語名→カラー(Hex)辞書。
/// GitHub Linguist(https://github.com/github-linguist/linguist)の`languages.yml`から
/// `color:`フィールドを持つ全エントリを抽出したもの。light/dark非依存の固定値として扱う。
struct LinguistColors: Sendable {
    let hexByLanguage: [String: String]

    static func loadBundled() -> LinguistColors {
        guard let url = Bundle.module.url(forResource: "LinguistColors", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            fatalError("LinguistColors.json is missing from the bundle")
        }
        do {
            return try decode(data)
        } catch {
            fatalError("LinguistColors.json is malformed: \(error)")
        }
    }

    static func decode(_ data: Data) throws -> LinguistColors {
        let raw = try JSONDecoder().decode([String: String].self, from: data)
        return LinguistColors(hexByLanguage: raw)
    }

    /// 未知の言語・不正なHex値の場合は`nil`（呼び出し側でフォールバック表示にする）。
    func color(for language: String) -> Color? {
        guard let hex = hexByLanguage[language] else { return nil }
        return Color(hex: hex)
    }
}

extension Color {
    /// "#RRGGBB"形式のHex文字列からColorを生成する。不正な形式なら`nil`。
    init?(hex: String) {
        var sanitized = hex
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }
        guard sanitized.count == 6, let value = UInt32(sanitized, radix: 16) else {
            return nil
        }
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self = Color(red: red, green: green, blue: blue)
    }
}
