import Foundation

struct Release: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let tagName: String
    let name: String?
    let body: String?
    let publishedAt: Date?
    let draft: Bool
    let prerelease: Bool
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case body
        case draft
        case prerelease
        case assets
        case tagName = "tag_name"
        case publishedAt = "published_at"
    }
}

struct ReleaseAsset: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let browserDownloadURL: URL
    let size: Int
    let contentType: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case browserDownloadURL = "browser_download_url"
        case contentType = "content_type"
    }
}
