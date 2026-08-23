import Foundation
import SwiftData
import Testing

@testable import Cairn

private func makeRepository(
    id: Int = 1,
    name: String = "repo",
    owner: String = "owner",
    fullName: String? = nil,
    topics: [String] = ["macos-app"],
    stargazersCount: Int = 10,
    language: String? = "Swift"
) -> Repository {
    Repository(
        id: id,
        name: name,
        fullName: fullName ?? "\(owner)/\(name)",
        owner: GitHubUser(
            id: 1,
            login: owner,
            avatarURL: URL(string: "https://example.com/avatar.png")!,
            htmlURL: URL(string: "https://github.com/\(owner)")!,
            type: "User"
        ),
        htmlURL: URL(string: "https://github.com/\(owner)/\(name)")!,
        description: nil,
        stargazersCount: stargazersCount,
        topics: topics,
        language: language,
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
struct SearchViewModelTests {
    // AppEnvironmentを戻り値のModelContextだけでなくインスタンスごと保持し続けないと、
    // スコープを抜けた時点でModelContainerが解放されクラッシュするため、
    // 各テストで環境そのものをローカル変数に束縛する（CachedRepositoryTestsと同様のパターン）。
    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(inMemory: true)
    }

    /// 条件が満たされるまで`Task.yield()`を繰り返し、非同期チェーンの完了を待つ。
    /// タイムアウトはテストインフラ側の安全弁であり、検証対象のデバウンス秒数とは無関係。
    private func pollUntil(_ condition: () async -> Bool, attempts: Int = 200) async {
        for _ in 0..<attempts {
            if await condition() { return }
            await Task.yield()
        }
    }

    @Test
    func debounceWaitsFullDurationBeforeCallingAPI() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let mockClient = MockGitHubClient()
        await mockClient.setSearchRepositoriesHandler { _, _ in
            SearchRepositoriesResult(totalCount: 0, incompleteResults: false, items: [])
        }
        let clock = ManualClock()
        let viewModel = SearchViewModel(gitHubClient: mockClient, modelContext: context, clock: clock)

        viewModel.queryText = "swift"
        await clock.waitForPendingSleep()

        await clock.advance(by: .milliseconds(299))
        for _ in 0..<10 { await Task.yield() }
        #expect(await mockClient.searchCallCount == 0)

        await clock.advance(by: .milliseconds(1))
        await pollUntil { await mockClient.searchCallCount == 1 }
        #expect(await mockClient.searchCallCount == 1)
    }

    @Test
    func duplicateQueryWithin5SecondsIsNotResent() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let mockClient = MockGitHubClient()
        await mockClient.setSearchRepositoriesHandler { _, _ in
            SearchRepositoriesResult(totalCount: 0, incompleteResults: false, items: [])
        }
        let clock = ManualClock()
        let viewModel = SearchViewModel(gitHubClient: mockClient, modelContext: context, clock: clock)

        viewModel.queryText = "swift"
        await clock.waitForPendingSleep()
        await clock.advance(by: .milliseconds(300))
        await pollUntil { await mockClient.searchCallCount == 1 }

        // 一度別のクエリへ変更してから同じ文字列へ戻す(didSetはoldValueとの差分でしか発火しないため)。
        viewModel.queryText = "swift2"
        await Task.yield()
        viewModel.queryText = "swift"
        await clock.waitForPendingSleep()
        await clock.advance(by: .milliseconds(300))
        for _ in 0..<20 { await Task.yield() }
        #expect(await mockClient.searchCallCount == 1)  // 5秒以内なので再送されない

        // 5秒経過後は同一クエリでも再送される。
        viewModel.queryText = "swift3"
        await Task.yield()
        viewModel.queryText = "swift"
        await clock.waitForPendingSleep()
        await clock.advance(by: .seconds(5))
        await pollUntil { await mockClient.searchCallCount == 2 }
        #expect(await mockClient.searchCallCount == 2)
    }

    @Test
    func cacheIsShownImmediatelyThenReplacedByAPIResult() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        context.insert(
            CachedRepository(
                githubId: 999,
                fullName: "owner/cached-repo",
                topics: ["macos-app"],
                starCount: 1,
                primaryLanguage: "Swift",
                htmlURL: "https://github.com/owner/cached-repo",
                category: "utilities",
                lastFetchedAt: Date(timeIntervalSince1970: 0)
            )
        )
        try context.save()

        let mockClient = MockGitHubClient()
        let apiRepository = makeRepository(id: 1, name: "new-repo", owner: "owner")
        await mockClient.setSearchRepositoriesHandler { _, _ in
            SearchRepositoriesResult(totalCount: 1, incompleteResults: false, items: [apiRepository])
        }
        await mockClient.setReleasesHandler { _, _ in [makeRelease()] }
        let clock = ManualClock()
        let viewModel = SearchViewModel(gitHubClient: mockClient, modelContext: context, clock: clock)

        viewModel.queryText = "repo"
        await clock.waitForPendingSleep()
        // デバウンス完了前は、キャッシュ内容がそのまま反映されている。
        #expect(viewModel.results.map(\.fullName) == ["owner/cached-repo"])

        await clock.advance(by: .milliseconds(300))
        await pollUntil { viewModel.results.map(\.fullName) == ["owner/new-repo"] }
        #expect(viewModel.results.map(\.fullName) == ["owner/new-repo"])
    }

    @Test
    func noiseFilterExcludesRepositoryWithoutValidAsset() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let mockClient = MockGitHubClient()
        let included = makeRepository(id: 1, name: "included", owner: "owner", topics: ["macos-app"])
        let excluded = makeRepository(id: 2, name: "excluded", owner: "owner", topics: ["macos-app"])
        await mockClient.setSearchRepositoriesHandler { _, _ in
            SearchRepositoriesResult(totalCount: 2, incompleteResults: false, items: [included, excluded])
        }
        await mockClient.setReleasesHandler { _, repo in
            repo == "included" ? [makeRelease(assetName: "App.dmg")] : [makeRelease(assetName: nil)]
        }
        let clock = ManualClock()
        let viewModel = SearchViewModel(gitHubClient: mockClient, modelContext: context, clock: clock)

        viewModel.queryText = "repo"
        await clock.waitForPendingSleep()
        await clock.advance(by: .milliseconds(300))
        await pollUntil { !viewModel.results.isEmpty }

        #expect(viewModel.results.map(\.fullName) == ["owner/included"])

        let cachedExcluded = try context.fetch(
            FetchDescriptor<CachedRepository>(predicate: #Predicate { $0.githubId == 2 })
        )
        #expect(cachedExcluded.isEmpty)
    }

    @Test
    func onlyFinalQueryAmongRapidChangesIsSentToAPI() async throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let mockClient = MockGitHubClient()
        await mockClient.setSearchRepositoriesHandler { _, _ in
            SearchRepositoriesResult(totalCount: 0, incompleteResults: false, items: [])
        }
        let clock = ManualClock()
        let viewModel = SearchViewModel(gitHubClient: mockClient, modelContext: context, clock: clock)

        viewModel.queryText = "s"
        viewModel.queryText = "sw"
        viewModel.queryText = "swi"
        viewModel.queryText = "swif"
        viewModel.queryText = "swift"
        await clock.waitForPendingSleep()

        await clock.advance(by: .milliseconds(300))
        await pollUntil { await mockClient.searchCallCount == 1 }

        let queries = await mockClient.recordedQueries
        #expect(queries.count == 1)
        #expect(queries.first?.hasPrefix("swift ") == true)
    }
}
