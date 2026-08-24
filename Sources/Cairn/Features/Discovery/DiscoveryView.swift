import SwiftUI

/// 検索中/トレンド選択中/カテゴリ選択中のいずれかに応じて`CategoryGridView`へ渡す表示状態。
private struct GridDisplayState {
    var repositories: [CachedRepository]
    var isLoading = false
    var errorMessage: String?
}

/// Discovery画面のルートView。
struct DiscoveryView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var discoveryViewModel: DiscoveryViewModel?
    @State private var searchViewModel: SearchViewModel<ContinuousClock>?
    @State private var trendingViewModel: TrendingViewModel?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selection: SidebarSelection = .all
    @State private var isPresentingSignIn = false

    var body: some View {
        Group {
            if let discoveryViewModel, let searchViewModel, let trendingViewModel {
                @Bindable var searchViewModel = searchViewModel
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(viewModel: discoveryViewModel, selection: $selection)
                } detail: {
                    let isSearching = !searchViewModel.queryText.isEmpty
                    let displayState: GridDisplayState =
                        if isSearching {
                            GridDisplayState(
                                repositories: searchViewModel.results,
                                isLoading: searchViewModel.isLoading,
                                errorMessage: searchViewModel.errorMessage
                            )
                        } else if selection == .trending {
                            GridDisplayState(
                                repositories: trendingViewModel.results,
                                isLoading: trendingViewModel.isLoading,
                                errorMessage: trendingViewModel.errorMessage
                            )
                        } else {
                            GridDisplayState(repositories: discoveryViewModel.repositoriesByCategory)
                        }
                    CategoryGridView(
                        repositories: displayState.repositories,
                        isLoading: displayState.isLoading,
                        errorMessage: displayState.errorMessage
                    )
                    .navigationTitle(isSearching ? "「\(searchViewModel.queryText)」の検索結果" : title(for: selection))
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            if appEnvironment.authenticationState.status == .unauthenticated {
                                Button {
                                    isPresentingSignIn = true
                                } label: {
                                    Label("サインイン", systemImage: "key.fill")
                                }
                                .help("サインインするとAPI呼び出しの上限が緩和されます")
                            }
                        }
                    }
                    .searchable(text: $searchViewModel.queryText, placement: .toolbar, prompt: "アプリを検索")
                    .sheet(isPresented: $isPresentingSignIn) {
                        DeviceFlowSignInView(authState: appEnvironment.authenticationState)
                    }
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                .onChange(of: selection) { _, newValue in
                    discoveryViewModel.selectedCategory = newValue.category
                }
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
            if trendingViewModel == nil {
                trendingViewModel = TrendingViewModel(
                    gitHubClient: appEnvironment.gitHubClient,
                    modelContext: appEnvironment.modelContainer.mainContext
                )
            }
            await trendingViewModel?.loadIfNeeded()
        }
    }

    private func title(for selection: SidebarSelection) -> String {
        switch selection {
        case .all: return "すべてのアプリ"
        case .trending: return "トレンド"
        case .category(let category): return category.displayName
        case .library: return "ライブラリ"
        }
    }
}
