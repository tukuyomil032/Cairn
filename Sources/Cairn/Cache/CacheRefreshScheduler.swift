import Defaults
import Foundation
import SwiftData

/// 起動時の軽量トップカテゴリ更新と、詳細画面遷移時のTTLベース遅延再検証を担う。
///
/// `SearchViewModel`とは責務が異なる：
/// - `SearchViewModel`: ユーザーの検索クエリ入力起因のAPI即応検索
/// - `CacheRefreshScheduler`: (a)起動時1回の「前回トップカテゴリ」更新、(b)詳細画面遷移時の
///   Releases/READMEのTTLベース遅延再検証
///
/// 両者は同じ`GitHubClientProtocol`/`ModelContext`を共有するが呼び出しタイミングが異なるため、
/// 1つのクラスに寄せず責務を分離する。
@MainActor
final class CacheRefreshScheduler {
    static let releaseTTL: TimeInterval = 60 * 60
    static let readmeTTL: TimeInterval = 60 * 60 * 24

    private let gitHubClient: GitHubClientProtocol
    private let modelContext: ModelContext
    private let noiseFilter: NoiseFiltering
    private let classifier: CategoryClassifying
    private let now: @Sendable () -> Date
    /// カテゴリからGitHub検索に使うキーワードを引く。デフォルトは`CategoryKeywords`の
    /// 代表キーワード（先頭の1件）を使う。`CategoryClassifier`のスコアリングと同じ辞書を参照するため、
    /// 検索結果が実際にそのカテゴリへ分類されやすいキーワードになる。
    private let keywordProvider: @Sendable (Category) -> String

    init(
        gitHubClient: GitHubClientProtocol,
        modelContext: ModelContext,
        noiseFilter: NoiseFiltering = NoiseFilter(),
        classifier: CategoryClassifying = CategoryClassifier(),
        now: @escaping @Sendable () -> Date = { Date() },
        keywordProvider: @escaping @Sendable (Category) -> String = { category in
            CategoryKeywords.loadBundled().keywordsByCategory[category]?.first ?? category.rawValue
        }
    ) {
        self.gitHubClient = gitHubClient
        self.modelContext = modelContext
        self.noiseFilter = noiseFilter
        self.classifier = classifier
        self.now = now
        self.keywordProvider = keywordProvider
    }

    /// アプリ起動時に1回だけ呼ぶ。前回トップカテゴリをDefaultsから読み出し、
    /// そのカテゴリに該当する検索を1回だけ実行してキャッシュへ反映する。
    /// 未設定（初回起動等）なら何もしない。
    ///
    /// 前回トップカテゴリの書き込み（カテゴリ選択時のDefaults更新）はPhase5のDiscovery UIで追加する。
    /// Phase4時点ではこのメソッドは読み出し専用として動作する。
    func refreshTopCategoryOnLaunch() async {
        guard let topCategory = Defaults[.lastTopCategory] else { return }

        let query = GitHubSearchQueryBuilder.build(from: keywordProvider(topCategory))
        do {
            let response = try await gitHubClient.searchRepositories(query: query, page: 1)
            for repository in response.items {
                let releases =
                    (try? await gitHubClient.releases(owner: repository.owner.login, repo: repository.name)) ?? []
                guard noiseFilter.shouldInclude(repository: repository, releases: releases) else { continue }
                let classification = classifier.classify(repository: repository, readme: nil)
                upsert(repository: repository, releases: releases, classification: classification)
            }
            try? modelContext.save()
        } catch {
            // 起動時の軽量更新失敗はサイレントに握りつぶす。キャッシュ済みデータで表示継続できるため。
        }
    }

    /// 詳細画面表示時に呼ぶ。Releases/READMEそれぞれのTTLを個別判定し、必要な分だけ取得して
    /// キャッシュへ反映する。
    ///
    /// `CachedRepository`は`Sendable`でないSwiftDataモデルのため、`async let`による並行実行は
    /// せず順に`await`する（どちらもTTL内ならほぼ即時returnするため、体感上の影響は小さい）。
    func revalidateDetailIfNeeded(for repository: CachedRepository) async {
        await revalidateReleasesIfNeeded(repository)
        await revalidateReadmeIfNeeded(repository)
    }

    private func revalidateReleasesIfNeeded(_ repository: CachedRepository) async {
        if let last = repository.lastReleaseCheckedAt, now().timeIntervalSince(last) < Self.releaseTTL {
            return
        }
        guard let (owner, repo) = splitOwnerRepo(repository.fullName) else { return }
        do {
            let releases = try await gitHubClient.releases(owner: owner, repo: repo)
            repository.releases = releases.map {
                CachedRelease(
                    tagName: $0.tagName,
                    assetNames: $0.assets.map(\.name),
                    assetURLs: $0.assets.map { $0.browserDownloadURL.absoluteString }
                )
            }
            repository.lastReleaseCheckedAt = now()
            try? modelContext.save()
        } catch {
            // 失敗時はTTLを更新しない（次回訪問時に再取得を試せるようにする）。
        }
    }

    private func revalidateReadmeIfNeeded(_ repository: CachedRepository) async {
        if let last = repository.lastReadmeFetchedAt, now().timeIntervalSince(last) < Self.readmeTTL {
            return
        }
        guard let (owner, repo) = splitOwnerRepo(repository.fullName) else { return }
        do {
            let readme = try await gitHubClient.readme(owner: owner, repo: repo)
            let classification = classifier.classify(
                topics: repository.topics,
                name: repo,
                readme: readme
            )
            repository.category = classification.category.rawValue
            repository.subTags = classification.subTags
            repository.lastReadmeFetchedAt = now()
            try? modelContext.save()
        } catch {
            // 失敗時はTTLを更新せず、既存分類（topics/名前のみ）を維持する。
            // 更新してしまうと24時間ずっと不正確な分類のまま固定されてしまうため、
            // 次回訪問時に再試行できるようにする。
        }
    }

    private func upsert(
        repository: Repository,
        releases: [Release],
        classification: ClassificationResult
    ) {
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
            existing.lastFetchedAt = now()
            existing.releases = cachedReleases
            return
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
            lastFetchedAt: now(),
            releases: cachedReleases
        )
        modelContext.insert(new)
    }

    private func splitOwnerRepo(_ fullName: String) -> (owner: String, repo: String)? {
        let parts = fullName.split(separator: "/", maxSplits: 1)
        guard parts.count == 2 else { return nil }
        return (String(parts[0]), String(parts[1]))
    }
}
