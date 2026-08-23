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
    /// GitHub Search APIの構文で、Swift/Objective-C/Objective-C++製リポジトリのみに絞り込む固定条件。
    /// ユーザー入力語と結合して1クエリにまとめる。
    static var languageFilter: String {
        #"language:Swift OR language:"Objective-C" OR language:"Objective-C++""#
    }

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
    private let noiseFilter: NoiseFiltering
    private let classifier: CategoryClassifying
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
        self.noiseFilter = noiseFilter
        self.classifier = classifier
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
            let apiQuery = buildAPIQuery(from: query)
            let response = try await gitHubClient.searchRepositories(query: apiQuery, page: 1)
            if Task.isCancelled { return }

            var reconciled: [CachedRepository] = []
            for repository in response.items {
                if Task.isCancelled { return }
                // ノイズ除去（dmg/zip資産チェック含む）は一覧段階で適用する。詳細画面遷移時のみ
                // 適用するより無駄なAPI呼び出しが増えるトレードオフを承知の上でのユーザー選択。
                // ダウンロードはせず、Releases一覧APIのassets[].nameを見るだけに留める。
                let releases =
                    (try? await gitHubClient.releases(owner: repository.owner.login, repo: repository.name)) ?? []
                guard noiseFilter.shouldInclude(repository: repository, releases: releases) else { continue }

                // README未取得のため、この段階ではtopics/名前のみでの分類になる
                // （README込みの再分類は詳細画面遷移時にCacheRefreshSchedulerが行う）。
                let classification = classifier.classify(repository: repository, readme: nil)
                reconciled.append(upsert(repository: repository, releases: releases, classification: classification))
            }
            try? modelContext.save()

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

    private func buildAPIQuery(from userInput: String) -> String {
        "\(userInput) \(Self.languageFilter)"
    }

    private func upsert(
        repository: Repository,
        releases: [Release],
        classification: ClassificationResult
    ) -> CachedRepository {
        let repositoryID = repository.id
        let descriptor = FetchDescriptor<CachedRepository>(
            predicate: #Predicate { $0.githubId == repositoryID }
        )
        let cachedReleases = releases.map {
            CachedRelease(
                tagName: $0.tagName,
                assetNames: $0.assets.map(\.name),
                assetURLs: $0.assets.map { $0.browserDownloadURL.absoluteString }
            )
        }

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.fullName = repository.fullName
            existing.topics = repository.topics
            existing.starCount = repository.stargazersCount
            existing.primaryLanguage = repository.language ?? ""
            existing.htmlURL = repository.htmlURL.absoluteString
            existing.category = classification.category.rawValue
            existing.subTags = classification.subTags
            existing.lastFetchedAt = Date()
            existing.releases = cachedReleases
            return existing
        }

        let new = CachedRepository(
            githubId: repository.id,
            fullName: repository.fullName,
            topics: repository.topics,
            starCount: repository.stargazersCount,
            primaryLanguage: repository.language ?? "",
            htmlURL: repository.htmlURL.absoluteString,
            category: classification.category.rawValue,
            subTags: classification.subTags,
            lastFetchedAt: Date(),
            releases: cachedReleases
        )
        modelContext.insert(new)
        return new
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
