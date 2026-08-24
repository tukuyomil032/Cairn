import Foundation
import SwiftData

/// GitHub検索APIの生の検索結果を「ノイズ除去→分類→SwiftDataへupsert」まで処理する共通ロジック。
///
/// `SearchViewModel`（ユーザー入力起因の検索）と`TrendingViewModel`（起動時の人気アプリ取得）の
/// 両方が同じ「検索結果をどう仕分けてキャッシュに反映するか」というロジックを必要とするため、
/// 重複させずここに切り出す。
@MainActor
struct RepositorySearchReconciler {
    let gitHubClient: GitHubClientProtocol
    let modelContext: ModelContext
    let noiseFilter: NoiseFiltering
    let classifier: CategoryClassifying

    /// `items`をノイズ除去・分類した上でSwiftDataへupsertし、採用されたリポジトリを返す。
    /// 呼び出し元の`Task`がキャンセルされた場合、その時点までに処理済みの結果を返して打ち切る
    /// （呼び出し元は`Task.isCancelled`を見て結果を反映するかどうかを判断する）。
    func reconcile(_ items: [Repository]) async -> [CachedRepository] {
        var reconciled: [CachedRepository] = []
        for repository in items {
            if Task.isCancelled { return reconciled }
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
        return reconciled
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
