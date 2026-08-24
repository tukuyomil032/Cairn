import Foundation
import Observation
import SwiftData

/// 検索クエリ入力に応じたstale-while-revalidate検索を担う。
///
/// `GitHubClientProtocol`/`ModelContext`をinitで直接受け取る疎結合設計。Phase5で本格的な
/// `AppEnvironment`（DIコンテナ）が整備されたら、そちらから注入するだけで差し替えられる。
///
/// レート制限自体は`GitHubClient`内部の`GitHubRateLimiter`が別途処理する。ここでの
/// デバウンス・重複クエリ抑制は「無駄なAPI呼び出し回数そのものを減らす」ためのUI層の責務であり、
/// `GitHubRateLimiter`の待機ロジックとは独立している（二重の待機にはならない）。
///
/// `ClockType`をジェネリックにしているのは、300msデバウンス・5秒重複抑制の判定をテストで
/// 実待機なしに検証するため。本番では`ContinuousClock`を使う便利initを用意する。
@Observable
@MainActor
final class SearchViewModel<ClockType: Clock> where ClockType.Duration == Duration {
    private static var debounceDuration: Duration { .milliseconds(300) }
    private static var duplicateSuppressionWindow: Duration { .seconds(5) }

    var queryText: String = "" {
        didSet {
            guard queryText != oldValue else { return }
            handleQueryTextChanged()
        }
    }
    private(set) var results: [CachedRepository] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let gitHubClient: GitHubClientProtocol
    private let modelContext: ModelContext
    private let reconciler: RepositorySearchReconciler
    private let clock: ClockType

    private var searchTask: Task<Void, Never>?
    private var lastSentQuery: String?
    private var lastSentAt: ClockType.Instant?

    init(
        gitHubClient: GitHubClientProtocol,
        modelContext: ModelContext,
        clock: ClockType,
        noiseFilter: NoiseFiltering = NoiseFilter(),
        classifier: CategoryClassifying = CategoryClassifier()
    ) {
        self.gitHubClient = gitHubClient
        self.modelContext = modelContext
        self.clock = clock
        self.reconciler = RepositorySearchReconciler(
            gitHubClient: gitHubClient,
            modelContext: modelContext,
            noiseFilter: noiseFilter,
            classifier: classifier
        )
    }

    private func handleQueryTextChanged() {
        searchTask?.cancel()
        let query = queryText
        searchTask = Task { [weak self] in
            await self?.performSearch(for: query)
        }
    }

    private func performSearch(for query: String) async {
        // stale-while-revalidateの"stale"部分: キャッシュを即座に反映する。
        loadFromCacheImmediately(query: query)

        guard !query.isEmpty else {
            // 空クエリでの全件API検索は無駄なので、キャッシュ一覧表示のみで完了する。
            return
        }

        do {
            try await clock.sleep(for: Self.debounceDuration)
        } catch {
            return  // 入力が続いてキャンセルされた
        }
        if Task.isCancelled { return }

        let isDuplicateWithinWindow =
            query == lastSentQuery
            && lastSentAt.map { $0.duration(to: clock.now) < Self.duplicateSuppressionWindow } == true
        if isDuplicateWithinWindow {
            // 直近5秒以内に同一クエリを送信済みなら、APIは叩かずキャッシュ表示のまま据え置く。
            return
        }

        await revalidateFromAPI(query: query)
    }

    private func loadFromCacheImmediately(query: String) {
        // SwiftDataの#Predicateでは配列(topics/subTags)への部分一致表現に限界があるため、
        // 全件取得後にSwift側でフィルタする（想定件数規模であれば許容範囲）。
        guard let all = try? modelContext.fetch(FetchDescriptor<CachedRepository>()) else {
            return
        }
        guard !query.isEmpty else {
            results = all
            return
        }
        results = all.filter { repository in
            repository.fullName.localizedCaseInsensitiveContains(query)
                || repository.topics.contains { $0.localizedCaseInsensitiveContains(query) }
                || repository.subTags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private func revalidateFromAPI(query: String) async {
        isLoading = true
        defer { isLoading = false }
        lastSentQuery = query
        lastSentAt = clock.now

        do {
            let apiQuery = GitHubSearchQueryBuilder.build(from: query)
            let response = try await gitHubClient.searchRepositories(query: apiQuery, page: 1)
            if Task.isCancelled { return }

            let reconciled = await reconciler.reconcile(response.items)

            errorMessage = nil
            if !Task.isCancelled {
                results = reconciled
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = "検索に失敗しました"
            }
        }
    }
}

extension SearchViewModel where ClockType == ContinuousClock {
    convenience init(
        gitHubClient: GitHubClientProtocol,
        modelContext: ModelContext,
        noiseFilter: NoiseFiltering = NoiseFilter(),
        classifier: CategoryClassifying = CategoryClassifier()
    ) {
        self.init(
            gitHubClient: gitHubClient,
            modelContext: modelContext,
            clock: ContinuousClock(),
            noiseFilter: noiseFilter,
            classifier: classifier
        )
    }
}
