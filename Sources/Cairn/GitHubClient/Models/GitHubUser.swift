import Foundation

struct GitHubUser: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let login: String
    let avatarURL: URL
    let htmlURL: URL
    let type: String

    enum CodingKeys: String, CodingKey {
        case id
        case login
        case type
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
    }
}
