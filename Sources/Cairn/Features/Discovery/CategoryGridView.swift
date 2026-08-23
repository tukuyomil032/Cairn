import SwiftUI

/// Discoveryのメインコンテンツ。カテゴリでフィルタされたリポジトリを`LazyVGrid`で並べる。
///
/// コンテンツ層のためLiquid Glassは使わず不透明背景を敷く（`docs/design/colors-and-materials.md`）。
struct CategoryGridView: View {
    var repositories: [CachedRepository]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.adaptive(minimum: 228), spacing: 16)]

    var body: some View {
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
        .background(Color(nsColor: .textBackgroundColor))
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
