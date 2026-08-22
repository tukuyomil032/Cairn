import Foundation
import SwiftData
import Testing

@testable import Cairn

@MainActor
@Suite(.serialized)
struct CachedReleaseTests {
    private func makeEnvironment() -> CairnEnvironment {
        CairnEnvironment(inMemory: true)
    }

    @Test
    func standaloneReleaseWithoutRepositoryCanBeSaved() throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let release = CachedRelease(
            tagName: "v0.1.0",
            assetNames: ["App.zip"],
            assetURLs: ["https://example.com/App.zip"]
        )
        context.insert(release)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CachedRelease>())

        #expect(fetched.count == 1)
        #expect(fetched.first?.repository == nil)
    }

    @Test
    func attachingMultipleReleasesReflectsOnRepositorySide() throws {
        let environment = makeEnvironment()
        let context = environment.modelContainer.mainContext
        let repository = CachedRepository(
            githubId: 3,
            fullName: "owner/inverse-repo",
            starCount: 0,
            primaryLanguage: "Swift",
            htmlURL: "https://github.com/owner/inverse-repo",
            category: "utilities",
            lastFetchedAt: Date(timeIntervalSince1970: 3000)
        )
        context.insert(repository)

        let releaseA = CachedRelease(tagName: "v1.0.0", repository: repository)
        let releaseB = CachedRelease(tagName: "v2.0.0", repository: repository)
        context.insert(releaseA)
        context.insert(releaseB)
        try context.save()

        #expect(repository.releases.count == 2)
    }
}
