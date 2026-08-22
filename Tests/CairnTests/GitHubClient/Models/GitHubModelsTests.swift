import Foundation
import Testing

@testable import Cairn

@Suite("GitHub APIモデルのデコード")
struct GitHubModelsTests {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @Test("GitHubUserを実レスポンス形式のJSONからデコードできる")
    func decodesGitHubUser() throws {
        let json = """
            {
                "id": 583231,
                "login": "octocat",
                "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4",
                "html_url": "https://github.com/octocat",
                "type": "User"
            }
            """
        let data = Data(json.utf8)

        let user = try Self.decoder.decode(GitHubUser.self, from: data)

        #expect(user.id == 583231)
        #expect(user.login == "octocat")
        #expect(user.type == "User")
    }

    @Test("Repositoryを実レスポンス形式のJSONからデコードできる")
    func decodesRepository() throws {
        let json = """
            {
                "id": 1296269,
                "name": "Hello-World",
                "full_name": "octocat/Hello-World",
                "owner": {
                    "id": 583231,
                    "login": "octocat",
                    "avatar_url": "https://avatars.githubusercontent.com/u/583231?v=4",
                    "html_url": "https://github.com/octocat",
                    "type": "User"
                },
                "html_url": "https://github.com/octocat/Hello-World",
                "description": "This your first repo!",
                "stargazers_count": 80,
                "topics": ["macos", "macos-app"],
                "language": "Swift",
                "updated_at": "2024-01-15T10:00:00Z",
                "pushed_at": "2024-01-10T10:00:00Z",
                "default_branch": "main",
                "archived": false,
                "fork": false
            }
            """
        let data = Data(json.utf8)

        let repository = try Self.decoder.decode(Repository.self, from: data)

        #expect(repository.fullName == "octocat/Hello-World")
        #expect(repository.owner.login == "octocat")
        #expect(repository.topics == ["macos", "macos-app"])
        #expect(repository.stargazersCount == 80)
        #expect(repository.archived == false)
    }

    @Test("Releaseとassetsを実レスポンス形式のJSONからデコードできる")
    func decodesRelease() throws {
        let json = """
            {
                "id": 1,
                "tag_name": "v1.0.0",
                "name": "v1.0.0",
                "body": "初回リリース",
                "published_at": "2024-01-20T10:00:00Z",
                "draft": false,
                "prerelease": false,
                "assets": [
                    {
                        "id": 11,
                        "name": "App.dmg",
                        "browser_download_url": "https://example.com/octocat/Hello-World/releases/App.dmg",
                        "size": 12345,
                        "content_type": "application/x-apple-diskimage"
                    }
                ]
            }
            """
        let data = Data(json.utf8)

        let release = try Self.decoder.decode(Release.self, from: data)

        #expect(release.tagName == "v1.0.0")
        #expect(release.assets.count == 1)
        #expect(release.assets[0].name == "App.dmg")
        #expect(release.assets[0].contentType == "application/x-apple-diskimage")
    }
}
