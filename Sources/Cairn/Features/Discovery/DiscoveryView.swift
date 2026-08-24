import SwiftUI

/// Discovery画面のルートView。
struct DiscoveryView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    @State private var discoveryViewModel: DiscoveryViewModel?
    @State private var searchViewModel: SearchViewModel<ContinuousClock>?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selection: SidebarSelection = .all
    @State private var isPresentingSignIn = false

    var body: some View {
        Group {
            if let discoveryViewModel, let searchViewModel {
                @Bindable var searchViewModel = searchViewModel
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(viewModel: discoveryViewModel, selection: $selection)
                } detail: {
                    CategoryGridView(repositories: discoveryViewModel.repositoriesByCategory)
                        .navigationTitle(title(for: selection))
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
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 320)
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
        }
    }

    private func title(for selection: SidebarSelection) -> String {
        switch selection {
        case .all: return "すべてのアプリ"
        case .category(let category): return category.displayName
        case .library: return "ライブラリ"
        }
    }
}
