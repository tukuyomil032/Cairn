import SwiftUI

/// Discoveryサイドバー本体。「すべてのアプリ」/`Category.allCases`（件数バッジ付き）/
/// 「ライブラリ」の行と、右上のpinned⇄unpinnedトグルボタンを表示する。「設定」はメニューバー
/// 常駐アイコンから開く方針のためサイドバーには含めない。
///
/// Liquid Glass適用領域（`docs/design/colors-and-materials.md`）: サイドバー背景は`.cairnGlass`。
struct SidebarView: View {
    var state: SidebarState
    var viewModel: DiscoveryViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                // ライブラリ画面自体はPhase8で実装。件数バッジは実装済みアプリ数と
                // 連携するまでは0固定のプレースホルダー。
                row(title: "ライブラリ", systemImage: "books.vertical", count: 0, isSelected: false) {}
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .cairnGlass(cornerRadius: 0)
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
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.pressable)
            .glassEffect(.regular.interactive(), in: .circle)
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
                .padding(.vertical, 4)
                .padding(.horizontal, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.pressable)
        .badge(count)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: isSelected)
    }
}
