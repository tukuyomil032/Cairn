import Defaults
import Foundation
import SwiftData
import Testing

@testable import Cairn

private func makeRepository(
    id: Int = 1,
    name: String = "repo",
    owner: String = "owner",
    topics: [String] = ["macos-app"]
) -> Repository {
    Repository(
        id: id,
        name: name,
        fullName: "\(owner)/\(name)",
        owner: GitHubUser(
            id: 1,
            login: owner,
            avatarURL: URL(string: "https://example.com/avatar.png")!,
            htmlURL: URL(string: "https://github.com/\(owner)")!,
            type: "User"
        ),
        htmlURL: URL(string: "https://github.com/\(owner)/\(name)")!,
        description: nil,
        stargazersCount: 10,
        topics: topics,
        language: "Swift",
        updatedAt: Date(timeIntervalSince1970: 0),
        pushedAt: Date(timeIntervalSince1970: 0),
        defaultBranch: "main",
        archived: false,
        fork: false
    )
}

private func makeRelease(assetName: String? = "App.dmg") -> Release {
    Release(
        id: 1,
        tagName: "v1.0.0",
        name: nil,
        body: nil,
        publishedAt: nil,
        draft: false,
        prerelease: false,
        assets: assetName.map {
            [
                ReleaseAsset(
                    id: 1,
                    name: $0,
                    browserDownloadURL: URL(string: "https://example.com/\($0)")!,
                    size: 100,
                    contentType: "application/octet-stream"
                )
            ]
        } ?? []
    )
}

@MainActor
@Suite(.serialized)
struct CacheRefreshSchedulerTests {
    // AppEnvironmentを戻り値のModelContextだけでなくインスタンスごと保持し続けないと、
    // スコープを抜けた時点でModelContainerが解放されクラッシュするため、
    // 各テストで環境そのものをローカル変数に束縛する（CachedRepositoryTestsと同様のパターン）。
    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(inMemory: true)
    }

    /// `Defaults[.lastTopCategory]`は`.standard`スイートを使う唯一のキーであり、他にこのキーへ
    /// 触れるテストは無いため、テスト前後で明示的にリセットすることでテスト間の独立性を保つ
    /// （専用UserDefaultsスイートへの切り替えは、書き込み側が実装されるPhase5でDefaultsKeys側の
    /// 設計と合わせて検討する）。
    private func withLastTopCategory<T>(_ category: Cairn.Category?, _ body: () async throws -> T) async rethrows -> T {
        let original = Defaults[.lastTopCategory]
        Defaults[.lastTopCategory] = category
        defer { Defaults[.lastTopCategory] = original }
        return try await body()
    }

    @Test
    func refreshesUsingLastTopCategoryOnLaunch() async throws {
        try await withLastTopCategory(Cairn.Category.developerTools) {
            let environment = makeEnvironment()
            let context = environment.modelContainer.mainContext
            let mockClient = MockGitHubClient()
            let repository = makeRepository()
            await mockClient.setSearchRepositoriesHandler { _, _ in
                SearchRepositoriesResult(totalCount: 1, incompleteResults: false, items: [repository])
            }
            await mockClient.setReleasesHandler { _, _ in [makeRelease()] }

            let scheduler = CacheRefreshScheduler(
                gitHubClient: mockClient,
                modelContext: context,
                keywordProvider: { _ in "cli" }
            )

            await scheduler.refreshTopCategoryOnLaunch()

            let queries = await mockClient.recordedQueries
            #expect(queries.count == 1)
            #expect(queries.first?.hasPrefix("cli ") == true)

            let cached = try context.fetch(FetchDescriptor<CachedRepository>())
            #expect(cached.map(\.fullName) == ["owner/repo"])
        }
    }

    @Test
    func doesNothingWhenNoTopCategoryIsSet() async throws {
        await withLastTopCategory(nil) {
            let environment = makeEnvironment()
            let context = environment.modelContainer.mainContext
            let mockClient = MockGitHubClient()
            let scheduler = CacheRefreshScheduler(gitHubClient: mockClient, modelContext: context)

            await scheduler.refreshTopCategoryOnLaunch()

            #expect(await mockClient.searchCallCount == 0)
        }
    }

    @Test
    func skipsReleasesFetchWhenWithinTTL() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let mockClient = MockGitHubClient()
        let fixedNow = Date(timeIntervalSince1970: 100_000)
        let repository = CachedRepository(
            githubId: 1,
            fullName: "owner/repo",
            starCount: 1,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/repo",
            category: "utilities",
            lastFetchedAt: fixedNow,
            lastReleaseCheckedAt: fixedNow.addingTimeInterval(-100)  // TTL(1時間)内
        )
        context.insert(repository)
        try context.save()

        let scheduler = CacheRefreshScheduler(gitHubClient: mockClient, modelContext: context, now: { fixedNow })
        await scheduler.revalidateDetailIfNeeded(for: repository)

        #expect(await mockClient.releasesCallCount == 0)
    }

    @Test
    func fetchesReleasesWhenTTLExpired() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let mockClient = MockGitHubClient()
        await mockClient.setReleasesHandler { _, _ in [makeRelease()] }
        let fixedNow = Date(timeIntervalSince1970: 100_000)
        let repository = CachedRepository(
            githubId: 1,
            fullName: "owner/repo",
            starCount: 1,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/repo",
            category: "utilities",
            lastFetchedAt: fixedNow,
            lastReleaseCheckedAt: fixedNow.addingTimeInterval(-CacheRefreshScheduler.releaseTTL - 1)
        )
        context.insert(repository)
        try context.save()

        let scheduler = CacheRefreshScheduler(gitHubClient: mockClient, modelContext: context, now: { fixedNow })
        await scheduler.revalidateDetailIfNeeded(for: repository)

        #expect(await mockClient.releasesCallCount == 1)
        #expect(repository.lastReleaseCheckedAt == fixedNow)
        #expect(repository.releases.map(\.tagName) == ["v1.0.0"])
    }

    @Test
    func skipsReadmeFetchWhenWithinTTL() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let mockClient = MockGitHubClient()
        let fixedNow = Date(timeIntervalSince1970: 100_000)
        let repository = CachedRepository(
            githubId: 1,
            fullName: "owner/repo",
            starCount: 1,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/repo",
            category: "utilities",
            lastFetchedAt: fixedNow,
            lastReleaseCheckedAt: fixedNow,  // ReleasesはTTL内にして今回の検証対象から外す
            lastReadmeFetchedAt: fixedNow.addingTimeInterval(-100)  // TTL(24時間)内
        )
        context.insert(repository)
        try context.save()

        let scheduler = CacheRefreshScheduler(gitHubClient: mockClient, modelContext: context, now: { fixedNow })
        await scheduler.revalidateDetailIfNeeded(for: repository)

        #expect(await mockClient.readmeCallCount == 0)
    }

    @Test
    func readmeFetchFailureDoesNotUpdateTTLOrCategory() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let mockClient = MockGitHubClient()
        await mockClient.setReadmeHandler { _, _ in throw GitHubClientError.httpError(statusCode: 500) }
        let fixedNow = Date(timeIntervalSince1970: 100_000)
        let staleReadmeFetchedAt = fixedNow.addingTimeInterval(-CacheRefreshScheduler.readmeTTL - 1)
        let repository = CachedRepository(
            githubId: 1,
            fullName: "owner/repo",
            starCount: 1,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/repo",
            category: "utilities",
            lastFetchedAt: fixedNow,
            lastReleaseCheckedAt: fixedNow,  // ReleasesはTTL内にして今回の検証対象から外す
            lastReadmeFetchedAt: staleReadmeFetchedAt
        )
        context.insert(repository)
        try context.save()

        let scheduler = CacheRefreshScheduler(gitHubClient: mockClient, modelContext: context, now: { fixedNow })
        await scheduler.revalidateDetailIfNeeded(for: repository)

        #expect(await mockClient.readmeCallCount == 1)
        #expect(repository.category == "utilities")  // 既存分類を維持
        #expect(repository.lastReadmeFetchedAt == staleReadmeFetchedAt)  // TTLを更新しない
    }
}
