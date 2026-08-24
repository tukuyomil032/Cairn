import SwiftUI

/// Discoveryのメインコンテンツ。カテゴリでフィルタされたリポジトリ、または検索結果を
/// `LazyVGrid`で並べる。
///
/// コンテンツ層のためLiquid Glassは使わず不透明背景を敷く（`docs/design/colors-and-materials.md`）。
struct CategoryGridView: View {
    var repositories: [CachedRepository]
    var isLoading: Bool = false
    var errorMessage: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.adaptive(minimum: 228), spacing: 16)]

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                statusBanner(text: "GitHubで最新結果を取得中…", systemImage: "arrow.triangle.2.circlepath")
            } else if let errorMessage {
                statusBanner(text: errorMessage, systemImage: "exclamationmark.triangle.fill", isError: true)
            }

            ScrollView {
                if repositories.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(repositories) { repository in
                            AppCardView(repository: repository)
                        }
                    }
                    .padding(20)
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: repositories.isEmpty)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    /// 検索の進行中・失敗を握りつぶさず表示する軽度エラーバナー
    /// （`docs/design/error-handling-ui.md`のパターン①）。
    private func statusBanner(text: String, systemImage: String, isError: Bool = false) -> some View {
        HStack(spacing: 8) {
            if isError {
                Image(systemName: systemImage)
                    .foregroundStyle(.orange)
            } else {
                ProgressView()
                    .controlSize(.small)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("表示できるアプリがありません")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
