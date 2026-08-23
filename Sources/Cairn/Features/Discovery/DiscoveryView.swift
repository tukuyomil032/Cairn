import SwiftUI

/// Discovery画面のルートView。
///
/// NavigationSplitViewは使わず、独自の`HStack`/`ZStack`レイアウトでpinned/unpinnedの
/// サイドバー挙動を実現する（`docs/design/sidebar-interaction.md`のXcodeナビゲータ同様の
/// ホバーオーバーレイ表示は、NavigationSplitViewの標準APIでは表現できず、かつ
/// NavigationSplitViewへのoverlay/ZStack併用にはnavigationTitleのスクロール挙動が壊れる
/// 既知の不具合報告があるため）。
struct DiscoveryView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var sidebarState = SidebarState()
    @State private var discoveryViewModel: DiscoveryViewModel?
    @State private var searchViewModel: SearchViewModel<ContinuousClock>?

    private static let sidebarWidth: CGFloat = 220
    private static let triggerZoneWidth: CGFloat = 16

    var body: some View {
        Group {
            if let discoveryViewModel, let searchViewModel {
                layout(discoveryViewModel: discoveryViewModel, searchViewModel: searchViewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if discoveryViewModel == nil {
                discoveryViewModel = DiscoveryViewModel(modelContext: appEnvironment.modelContainer.mainContext)
            }
            if searchViewModel == nil {
                searchViewModel = SearchViewModel(
                    gitHubClient: appEnvironment.gitHubClient,
                    modelContext: appEnvironment.modelContainer.mainContext
                )
            }
        }
    }

    /// pinned/unpinnedで`HStack`/`ZStack`を丸ごと入れ替えるとSwiftUIが両状態の差分を
    /// 見出せずアニメーションできないため、常に同じ`HStack`をルートにし、その中で
    /// サイドバーの有無・ホバーオーバーレイの有無を`if`で切り替える設計に統一している。
    private func layout(discoveryViewModel: DiscoveryViewModel, searchViewModel: SearchViewModel<ContinuousClock>)
        -> some View
    {
        HStack(spacing: 0) {
            if sidebarState.isPinned {
                SidebarView(state: sidebarState, viewModel: discoveryViewModel)
                    .frame(width: Self.sidebarWidth)
                    .transition(.move(edge: .leading))
                Divider()
            }

            ZStack(alignment: .leading) {
                content(discoveryViewModel: discoveryViewModel, searchViewModel: searchViewModel)
                    .frame(maxWidth: .infinity)

                if !sidebarState.isPinned {
                    Color.clear
                        .frame(width: Self.triggerZoneWidth)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering { sidebarState.hoverEntered() } else { sidebarState.hoverExited() }
                        }

                    if sidebarState.isRevealed {
                        SidebarView(state: sidebarState, viewModel: discoveryViewModel)
                            .frame(width: Self.sidebarWidth)
                            .shadow(radius: 12, x: 4)
                            .onHover { hovering in
                                if hovering { sidebarState.hoverEntered() } else { sidebarState.hoverExited() }
                            }
                            .transition(reduceMotion ? .identity : .move(edge: .leading))
                    }
                }
            }
            // ZStack自体（常に存在する親）に付与することで、isRevealedがtrue→falseに
            // なる瞬間もこの修飾子がツリーに残り続け、退場アニメーションが機能する
            // （if節の内側に付与すると、falseになった瞬間に修飾子ごと消えてしまう）。
            .animation(reduceMotion ? nil : .bouncy(duration: 0.4), value: sidebarState.isRevealed)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: sidebarState.isPinned)
    }

    private func content(
        discoveryViewModel: DiscoveryViewModel,
        searchViewModel: SearchViewModel<ContinuousClock>
    ) -> some View {
        VStack(spacing: 0) {
            SearchBarView(searchViewModel: searchViewModel, authenticationState: appEnvironment.authenticationState)
            CategoryGridView(repositories: discoveryViewModel.repositoriesByCategory)
                .id(discoveryViewModel.selectedCategory)
                .transition(.opacity)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.2),
                    value: discoveryViewModel.selectedCategory
                )
        }
    }
}
