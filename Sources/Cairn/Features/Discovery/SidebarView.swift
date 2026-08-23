import SwiftUI

/// Discoveryサイドバー本体。「すべてのアプリ」/`Category.allCases`（件数バッジ付き）/
/// 「ライブラリ」/「設定」の行と、右上のpinned⇄unpinnedトグルボタンを表示する。
///
/// Liquid Glass適用領域（`docs/design/colors-and-materials.md`）: サイドバー背景は`.thickMaterial`。
struct SidebarView: View {
    var state: SidebarState
    var viewModel: DiscoveryViewModel

    private var totalCount: Int {
        viewModel.categoryCounts.values.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            List {
                row(
                    title: "すべてのアプリ", systemImage: "square.grid.2x2", count: totalCount,
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectedCategory = nil
                }

                Section("カテゴリ") {
                    ForEach(Category.allCases, id: \.self) { category in
                        row(
                            title: category.displayName,
                            systemImage: category.sfSymbolName,
                            count: viewModel.categoryCounts[category] ?? 0,
                            isSelected: viewModel.selectedCategory == category
                        ) {
                            viewModel.selectedCategory = category
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Label("ライブラリ", systemImage: "books.vertical")
                Label("設定", systemImage: "gearshape")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.thickMaterial)
    }

    private var header: some View {
        HStack {
            Text("Cairn")
                .font(.headline)
            Spacer()
            Button {
                state.togglePinned()
            } label: {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(state.isPinned ? "サイドバーのピン留めを解除" : "サイドバーをピン留め")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func row(
        title: String,
        systemImage: String,
        count: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .badge(count)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
    }
}
