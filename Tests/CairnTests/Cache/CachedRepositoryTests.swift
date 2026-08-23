import Foundation
import SwiftData
import Testing

@testable import Cairn

@MainActor
@Suite(.serialized)
struct CachedRepositoryTests {
    // AppEnvironmentを戻り値のModelContextだけでなくインスタンスごと保持し続けないと、
    // スコープを抜けた時点でModelContainerが解放されクラッシュするため、
    // 各テストで環境そのものをローカル変数に束縛する。
    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(inMemory: true)
    }

    @Test
    func insertedRepositoryCanBeFetchedBack() throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let repository = CachedRepository(
            githubId: 1,
            fullName: "owner/repo",
            topics: ["macos-app"],
            starCount: 42,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/repo",
            category: "utilities",
            subTags: ["cli"],
            lastFetchedAt: Date(timeIntervalSince1970: 1000)
        )
        context.insert(repository)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CachedRepository>())

        #expect(fetched.count == 1)
        #expect(fetched.first?.fullName == "owner/repo")
        #expect(fetched.first?.starCount == 42)
        #expect(fetched.first?.lastReleaseCheckedAt == nil)
        #expect(fetched.first?.lastReadmeFetchedAt == nil)
    }

    @Test
    func lastReadmeFetchedAtIsPersistedAcrossFetch() throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let readmeFetchedAt = Date(timeIntervalSince1970: 3000)
        let repository = CachedRepository(
            githubId: 3,
            fullName: "owner/readme-repo",
            starCount: 5,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/readme-repo",
            category: "utilities",
            lastFetchedAt: Date(timeIntervalSince1970: 1000),
            lastReadmeFetchedAt: readmeFetchedAt
        )
        context.insert(repository)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CachedRepository>())

        #expect(fetched.first?.lastReadmeFetchedAt == readmeFetchedAt)
    }

    @Test
    func duplicateGithubIdOverwritesExistingRecord() throws {
        // SwiftDataの`.unique`制約は例外を投げず、既存レコードを上書き(upsert)する挙動を
        // 実機で確認済み。よってエラーではなく1件に集約されることを期待値とする。
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext

        context.insert(
            CachedRepository(
                githubId: 10,
                fullName: "owner/first",
                starCount: 1,
                primaryLanguage: "Swift",
                htmlURL: "https://github.com/owner/first",
                category: "utilities",
                lastFetchedAt: Date(timeIntervalSince1970: 1000)
            )
        )
        try context.save()

        context.insert(
            CachedRepository(
                githubId: 10,
                fullName: "owner/second",
                starCount: 2,
                primaryLanguage: "Swift",
                htmlURL: "https://github.com/owner/second",
                category: "utilities",
                lastFetchedAt: Date(timeIntervalSince1970: 2000)
            )
        )
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CachedRepository>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.fullName == "owner/second")
    }

    @Test
    func deletingRepositoryCascadesToItsReleases() throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let repository = CachedRepository(
            githubId: 2,
            fullName: "owner/cascade-repo",
            starCount: 0,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/cascade-repo",
            category: "utilities",
            lastFetchedAt: Date(timeIntervalSince1970: 2000),
            releases: [
                CachedRelease(tagName: "v1.0.0"),
                CachedRelease(tagName: "v1.1.0"),
            ]
        )
        context.insert(repository)
        try context.save()

        context.delete(repository)
        try context.save()

        let remainingReleases = try context.fetch(FetchDescriptor<CachedRelease>())
        #expect(remainingReleases.isEmpty)
    }
}
