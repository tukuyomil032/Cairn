import SwiftUI

/// 設定画面の暫定プレースホルダー。
///
/// 本格的な設定項目（アカウント状態表示・ログアウト・キャッシュクリア・Sparkle設定）は
/// Phase11で実装する（`docs/progress.md`参照）。Phase5時点では、設定へのエントリポイントを
/// サイドバーからメニューバー常駐アイコンへ移す方針転換に伴い、最低限開けるウィンドウとして
/// このプレースホルダーを用意している。
struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gearshape")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("設定はまだ実装されていません")
                .font(.headline)
            Text("アカウント・キャッシュ・アップデートの設定はPhase11で追加予定です。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(width: 360, height: 240)
    }
}
