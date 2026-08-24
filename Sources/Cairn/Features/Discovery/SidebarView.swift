import SwiftUI

/// Discoveryサイドバー本体。「すべてのアプリ」/`Category.allCases`（件数バッジ付き）/
/// 「ライブラリ」の行を表示する。
///
/// `NavigationSplitView`の中で使う前提のため、開閉トグル・背景マテリアルはすべてAppleが
/// 自動的に描画するものに任せ、このView自身は`List(selection:)`の中身だけを持つ
/// （`msitarzewski/brew-browser`のサイドバー実装を参考に、独自の見た目・状態管理を持たない
/// 方針にした）。「設定」はメニューバー常駐アイコンから開く方針のためサイドバーには含めない。
struct SidebarView: View {
    var viewModel: DiscoveryViewModel
    @Binding var selection: SidebarSelection

    private var totalCount: Int {
        viewModel.categoryCounts.values.reduce(0, +)
    }

    var body: some View {
        List(selection: $selection) {
            Label("すべてのアプリ", systemImage: "square.grid.2x2")
                .badge(totalCount)
                .tag(SidebarSelection.all)

            // 起動時に1回だけ取得する人気macOSアプリ一覧（言語不問、TrendingViewModel）。
            Label("トレンド", systemImage: "flame")
                .tag(SidebarSelection.trending)

            Section("カテゴリ") {
                ForEach(Category.allCases, id: \.self) { category in
                    Label(category.displayName, systemImage: category.sfSymbolName)
                        .badge(viewModel.categoryCounts[category] ?? 0)
                        .tag(SidebarSelection.category(category))
                }
            }

            // ライブラリ画面自体はPhase8で実装。件数バッジは実装済みアプリ数と
            // 連携するまでは付けない。
            Label("ライブラリ", systemImage: "books.vertical")
                .tag(SidebarSelection.library)
        }
        .navigationTitle("Cairn")
    }
}
