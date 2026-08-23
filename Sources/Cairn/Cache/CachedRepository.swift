import Foundation
import SwiftData

@Model
final class CachedRepository {
    @Attribute(.unique) var githubId: Int
    var fullName: String
    var topics: [String]
    var starCount: Int
    var primaryLanguage: String
    var htmlURL: String
    // Phase3のCategory enumのrawValue相当。Phase2ではCategory型に依存させず素のStringのまま持つ。
    var category: String
    var subTags: [String]
    var lastFetchedAt: Date
    var lastReleaseCheckedAt: Date?
    var lastReadmeFetchedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \CachedRelease.repository)
    var releases: [CachedRelease]

    init(
        githubId: Int,
        fullName: String,
        topics: [String] = [],
        starCount: Int,
        primaryLanguage: String,
        htmlURL: String,
        category: String,
        subTags: [String] = [],
        lastFetchedAt: Date,
        lastReleaseCheckedAt: Date? = nil,
        lastReadmeFetchedAt: Date? = nil,
        releases: [CachedRelease] = []
    ) {
        self.githubId = githubId
        self.fullName = fullName
        self.topics = topics
        self.starCount = starCount
        self.primaryLanguage = primaryLanguage
        self.htmlURL = htmlURL
        self.category = category
        self.subTags = subTags
        self.lastFetchedAt = lastFetchedAt
        self.lastReleaseCheckedAt = lastReleaseCheckedAt
        self.lastReadmeFetchedAt = lastReadmeFetchedAt
        self.releases = releases
    }
}
