import SwiftUI

/// Discoveryのメインコンテンツ。カテゴリでフィルタされたリポジトリ、または検索結果を
/// `LazyVGrid`で並べる。
///
/// コンテンツ層のためLiquid Glassは使わず不透明背景を敷く（`docs/design/colors-and-materials.md`）。
struct CategoryGridView: View {
    var repositories: [CachedRepository]
    var isLoading: Bool = false
    var errorMessage: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.adaptive(minimum: 228), spacing: 16)]

    var body: some View {
        ScrollView {
            if isLoading {
                statusState(systemImage: "arrow.triangle.2.circlepath", text: "GitHubで取得中…", animated: true)
                    .transition(.opacity)
            } else if let errorMessage {
                statusState(systemImage: "exclamationmark.triangle.fill", text: errorMessage)
                    .transition(.opacity)
            } else if !repositories.isEmpty {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(repositories) { repository in
                        AppCardView(repository: repository)
                    }
                }
                .padding(20)
                .transition(.opacity)
            }
            // repositoriesが空でロード中でもエラーでもない場合は何も表示しない
            // （空状態メッセージは要件により廃止した）。
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: statusKey)
        .background(Color(nsColor: .textBackgroundColor))
    }

    /// アニメーション対象を切り替えるための識別子（ロード中/エラー/一覧の3状態のみを区別すればよく、
    /// `repositories`配列自体の内容比較は不要）。
    private var statusKey: Int {
        if isLoading { return 0 }
        if errorMessage != nil { return 1 }
        return repositories.isEmpty ? 2 : 3
    }

    /// ロード中・エラーを画面中央にSF Symbolsで表示する
    /// （`docs/design/error-handling-ui.md`のパターン②、握りつぶさない）。
    private func statusState(systemImage: String, text: String, animated: Bool = false) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .symbolEffect(.rotate, options: animated ? .repeating : .nonRepeating, isActive: animated)
            Text(text)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }
}
