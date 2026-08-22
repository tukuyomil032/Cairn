import Foundation

struct Repository: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let fullName: String
    let owner: GitHubUser
    let htmlURL: URL
    let description: String?
    let stargazersCount: Int
    let topics: [String]
    let language: String?
    let updatedAt: Date
    let pushedAt: Date
    let defaultBranch: String
    let archived: Bool
    let fork: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case owner
        case description
        case topics
        case language
        case archived
        case fork
        case fullName = "full_name"
        case htmlURL = "html_url"
        case stargazersCount = "stargazers_count"
        case updatedAt = "updated_at"
        case pushedAt = "pushed_at"
        case defaultBranch = "default_branch"
    }
}
