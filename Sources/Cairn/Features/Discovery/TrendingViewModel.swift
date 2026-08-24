import Observation
import SwiftData

/// 起動時に1回だけGitHubを検索し、人気のmacOSアプリ（トレンド）を取得する。
///
/// `SearchViewModel`と違い、デバウンスや重複クエリ抑制は不要（ユーザー入力に反応する
/// 逐次検索ではなく、起動時の一発検索のため）。そのため`ClockType`ジェネリックも持たない
/// 単純な設計にしている。検索結果の仕分け（ノイズ除去→分類→SwiftDataへupsert）は
/// `SearchViewModel`と共有の`RepositorySearchReconciler`に委ねる。
@Observable
@MainActor
final class TrendingViewModel {
    private(set) var results: [CachedRepository] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let gitHubClient: GitHubClientProtocol
    private let reconciler: RepositorySearchReconciler
    private var hasLoaded = false

    init(
        gitHubClient: GitHubClientProtocol,
        modelContext: ModelContext,
        noiseFilter: NoiseFiltering = NoiseFilter(),
        classifier: CategoryClassifying = CategoryClassifier()
    ) {
        self.gitHubClient = gitHubClient
        self.reconciler = RepositorySearchReconciler(
            gitHubClient: gitHubClient,
            modelContext: modelContext,
            noiseFilter: noiseFilter,
            classifier: classifier
        )
    }

    /// 起動時に1回だけ呼ぶ。既に読み込み済み・読み込み中の場合は何もしない
    /// （`DiscoveryView`の`.task`が再実行されても二重に取得しないため）。
    func loadIfNeeded() async {
        guard !hasLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await gitHubClient.searchRepositories(
                query: GitHubSearchQueryBuilder.trendingQuery,
                page: 1,
                sort: "stars",
                order: "desc"
            )
            results = await reconciler.reconcile(response.items)
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "トレンドの取得に失敗しました"
        }
    }
}
