import Foundation
import Testing

@testable import Cairn

// StubURLProtocolがプロセス全体で共有されるため、テスト同士の並列実行による
// スタブの取り合いを避けるためシリアル実行にする。
@Suite("GitHubClientのエンドポイント呼び出し", .serialized)
struct GitHubClientTests {
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func makeClient(accessToken: String? = nil) -> GitHubClient {
        GitHubClient(
            baseURL: URL(string: "https://api.github.com")!,
            session: makeSession(),
            accessTokenProvider: { accessToken }
        )
    }

    @Test("searchRepositoriesがitemsをデコードして返す")
    func searchRepositoriesDecodesItems() async throws {
        StubURLProtocol.reset()
        let body = """
            {
                "total_count": 1,
                "incomplete_results": false,
                "items": [
                    {
                        "id": 1,
                        "name": "Repo",
                        "full_name": "octocat/Repo",
                        "owner": {
                            "id": 1,
                            "login": "octocat",
                            "avatar_url": "https://example.com/a.png",
                            "html_url": "https://github.com/octocat",
                            "type": "User"
                        },
                        "html_url": "https://github.com/octocat/Repo",
                        "description": null,
                        "stargazers_count": 5,
                        "topics": ["macos"],
                        "language": "Swift",
                        "updated_at": "2024-01-15T10:00:00Z",
                        "pushed_at": "2024-01-10T10:00:00Z",
                        "default_branch": "main",
                        "archived": false,
                        "fork": false
                    }
                ]
            }
            """
        StubURLProtocol.stub(path: "/search/repositories", body: Data(body.utf8))

        let client = Self.makeClient()
        let result = try await client.searchRepositories(query: "language:Swift", page: 1)

        #expect(result.totalCount == 1)
        #expect(result.items.first?.fullName == "octocat/Repo")
    }

    @Test("searchRepositoriesにsort/orderを渡すとクエリパラメータに反映される")
    func searchRepositoriesAppliesSortAndOrder() async throws {
        StubURLProtocol.reset()
        let body = """
            {"total_count": 0, "incomplete_results": false, "items": []}
            """
        StubURLProtocol.stub(path: "/search/repositories", body: Data(body.utf8))

        let client = Self.makeClient()
        _ = try await client.searchRepositories(query: "topic:macos", page: 1, sort: "stars", order: "desc")

        let requests = StubURLProtocol.recordedRequests(matching: "/search/repositories")
        let components = URLComponents(url: requests.last!.url!, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []
        #expect(queryItems.contains(URLQueryItem(name: "sort", value: "stars")))
        #expect(queryItems.contains(URLQueryItem(name: "order", value: "desc")))
    }

    @Test("sort/orderを省略するとクエリパラメータに含まれない")
    func searchRepositoriesOmitsSortAndOrderWhenNil() async throws {
        StubURLProtocol.reset()
        let body = """
            {"total_count": 0, "incomplete_results": false, "items": []}
            """
        StubURLProtocol.stub(path: "/search/repositories", body: Data(body.utf8))

        let client = Self.makeClient()
        _ = try await client.searchRepositories(query: "language:Swift", page: 1)

        let requests = StubURLProtocol.recordedRequests(matching: "/search/repositories")
        let components = URLComponents(url: requests.last!.url!, resolvingAgainstBaseURL: false)!
        let queryItems = components.queryItems ?? []
        #expect(!queryItems.contains { $0.name == "sort" })
        #expect(!queryItems.contains { $0.name == "order" })
    }

    @Test("releasesが配列をデコードして返す")
    func releasesDecodesArray() async throws {
        StubURLProtocol.reset()
        let body = "[{\"id\": 1, \"tag_name\": \"v1.0.0\", \"draft\": false, \"prerelease\": false, \"assets\": []}]"
        StubURLProtocol.stub(path: "/repos/octocat/Repo/releases", body: Data(body.utf8))

        let client = Self.makeClient()
        let releases = try await client.releases(owner: "octocat", repo: "Repo")

        #expect(releases.count == 1)
        #expect(releases[0].tagName == "v1.0.0")
    }

    @Test("readmeがbase64本文をデコードして返す")
    func readmeDecodesBase64Content() async throws {
        StubURLProtocol.reset()
        let markdown = "# Hello"
        let base64 = Data(markdown.utf8).base64EncodedString()
        let body = "{\"content\": \"\(base64)\", \"encoding\": \"base64\"}"
        StubURLProtocol.stub(path: "/repos/octocat/Repo/readme", body: Data(body.utf8))

        let client = Self.makeClient()
        let readme = try await client.readme(owner: "octocat", repo: "Repo")

        #expect(readme == markdown)
    }

    @Test("readmeが404の場合はnilを返す（README未登録の正常系）")
    func readmeReturnsNilOn404() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.stub(path: "/repos/octocat/Repo/readme", statusCode: 404, body: Data())

        let client = Self.makeClient()
        let readme = try await client.readme(owner: "octocat", repo: "Repo")

        #expect(readme == nil)
    }

    @Test("authenticatedUserは未認証だとネットワークを叩かずunauthenticatedを投げる")
    func authenticatedUserThrowsWhenNoToken() async throws {
        StubURLProtocol.reset()
        let client = Self.makeClient(accessToken: nil)

        await #expect(throws: GitHubClientError.unauthenticated) {
            try await client.authenticatedUser()
        }
        #expect(StubURLProtocol.recordedRequests(matching: "/user").isEmpty)
    }

    @Test("authenticatedUserはトークンがあればAuthorizationヘッダーを付与してリクエストする")
    func authenticatedUserSendsBearerToken() async throws {
        StubURLProtocol.reset()
        let body = """
            {
                "id": 1, "login": "octocat",
                "avatar_url": "https://example.com/a.png",
                "html_url": "https://github.com/octocat",
                "type": "User"
            }
            """
        StubURLProtocol.stub(path: "/user", body: Data(body.utf8))

        let client = Self.makeClient(accessToken: "test-token")
        let user = try await client.authenticatedUser()

        #expect(user.login == "octocat")
        let request = StubURLProtocol.recordedRequests(matching: "/user").first
        #expect(request?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test("401を受けるとtokenInvalidを投げる")
    func throwsTokenInvalidOn401() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.stub(path: "/user", statusCode: 401, body: Data())

        let client = Self.makeClient(accessToken: "expired-token")

        await #expect(throws: GitHubClientError.tokenInvalid) {
            try await client.authenticatedUser()
        }
    }

    @Test("401を受けるとonUnauthorizedフックが呼ばれる（AuthenticationStateの.tokenInvalid遷移をトリガーする配線点）")
    func callsOnUnauthorizedHookOn401() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.stub(path: "/user", statusCode: 401, body: Data())
        let recorder = UnauthorizedCallRecorder()
        let client = GitHubClient(
            baseURL: URL(string: "https://api.github.com")!,
            session: Self.makeSession(),
            accessTokenProvider: { "expired-token" },
            onUnauthorized: { await recorder.markCalled() }
        )

        _ = try? await client.authenticatedUser()

        #expect(await recorder.wasCalled)
    }

    @Test("403を受けるとrateLimitedを投げる")
    func throwsRateLimitedOn403() async throws {
        StubURLProtocol.reset()
        StubURLProtocol.stub(path: "/search/repositories", statusCode: 403, body: Data())

        let client = Self.makeClient()

        await #expect(throws: GitHubClientError.rateLimited) {
            try await client.searchRepositories(query: "language:Swift", page: 1)
        }
    }
}

/// `onUnauthorized`フックが呼ばれたかどうかを記録するテスト用ヘルパー。
private actor UnauthorizedCallRecorder {
    private(set) var wasCalled = false

    func markCalled() {
        wasCalled = true
    }
}
