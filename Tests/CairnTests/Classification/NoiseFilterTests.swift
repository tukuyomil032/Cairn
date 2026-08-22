import Foundation
import Testing

@testable import Cairn

@Suite("ノイズ除去フィルタ")
struct NoiseFilterTests {
    private func makeRepository(topics: [String]) -> Repository {
        Repository(
            id: 1,
            name: "SampleApp",
            fullName: "owner/SampleApp",
            owner: GitHubUser(
                id: 1,
                login: "owner",
                avatarURL: URL(string: "https://example.com/avatar.png")!,
                htmlURL: URL(string: "https://github.com/owner")!,
                type: "User"
            ),
            htmlURL: URL(string: "https://github.com/owner/SampleApp")!,
            description: nil,
            stargazersCount: 0,
            topics: topics,
            language: "Swift",
            updatedAt: Date(timeIntervalSince1970: 0),
            pushedAt: Date(timeIntervalSince1970: 0),
            defaultBranch: "main",
            archived: false,
            fork: false
        )
    }

    private func makeRelease(assetNames: [String]) -> Release {
        Release(
            id: 1,
            tagName: "v1.0.0",
            name: nil,
            body: nil,
            publishedAt: nil,
            draft: false,
            prerelease: false,
            assets: assetNames.enumerated().map { index, name in
                ReleaseAsset(
                    id: index,
                    name: name,
                    browserDownloadURL: URL(string: "https://example.com/\(name)")!,
                    size: 0,
                    contentType: "application/octet-stream"
                )
            }
        )
    }

    @Test("topicsとdmg資産の両方があれば含める")
    func includesWhenTopicAndDmgAssetPresent() {
        let filter = NoiseFilter()
        let repository = makeRepository(topics: ["macos"])
        let releases = [makeRelease(assetNames: ["App.dmg"])]

        #expect(filter.shouldInclude(repository: repository, releases: releases))
    }

    @Test("topicsはあるが資産がなければ除外する")
    func excludesWhenNoAsset() {
        let filter = NoiseFilter()
        let repository = makeRepository(topics: ["macos"])
        let releases = [makeRelease(assetNames: [])]

        #expect(!filter.shouldInclude(repository: repository, releases: releases))
    }

    @Test("topicsがなければ資産があっても除外する")
    func excludesWhenNoRequiredTopic() {
        let filter = NoiseFilter()
        let repository = makeRepository(topics: ["cli"])
        let releases = [makeRelease(assetNames: ["App.dmg"])]

        #expect(!filter.shouldInclude(repository: repository, releases: releases))
    }

    @Test("topicsも資産もなければ除外する")
    func excludesWhenNeitherTopicNorAsset() {
        let filter = NoiseFilter()
        let repository = makeRepository(topics: [])
        let releases = [makeRelease(assetNames: [])]

        #expect(!filter.shouldInclude(repository: repository, releases: releases))
    }

    @Test(".pkgのみの資産は対象外とする")
    func excludesPkgOnlyAssets() {
        let filter = NoiseFilter()
        let repository = makeRepository(topics: ["macos-app"])
        let releases = [makeRelease(assetNames: ["Installer.pkg"])]

        #expect(!filter.shouldInclude(repository: repository, releases: releases))
    }

    @Test("複数リリースのうちいずれかがdmg資産を持てば含める")
    func includesWhenAnyReleaseHasValidAsset() {
        let filter = NoiseFilter()
        let repository = makeRepository(topics: ["macos"])
        let releases = [
            makeRelease(assetNames: ["notes.txt"]),
            makeRelease(assetNames: ["App.dmg"]),
        ]

        #expect(filter.shouldInclude(repository: repository, releases: releases))
    }

    @Test("topicsの大文字小文字が異なっても一致する")
    func matchesTopicsCaseInsensitively() {
        let filter = NoiseFilter()
        let repository = makeRepository(topics: ["MacOS"])
        let releases = [makeRelease(assetNames: ["App.zip"])]

        #expect(filter.shouldInclude(repository: repository, releases: releases))
    }
}
