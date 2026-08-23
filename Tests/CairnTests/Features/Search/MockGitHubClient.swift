import Foundation

@testable import Cairn

/// `SearchViewModel`のテスト用に、呼び出し回数・クエリ文字列を記録する`GitHubClientProtocol`モック。
/// 可変状態を持つため`actor`にして、`SearchViewModel`（`@MainActor`）からの並行アクセスを安全にする。
actor MockGitHubClient: GitHubClientProtocol {
    var searchRepositoriesHandler: (@Sendable (String, Int) async throws -> SearchRepositoriesResult)?
    var releasesHandler: (@Sendable (String, String) async throws -> [Release])?
    var readmeHandler: (@Sendable (String, String) async throws -> String?)?

    private(set) var searchCallCount = 0
    private(set) var recordedQueries: [String] = []
    private(set) var releasesCallCount = 0
    private(set) var readmeCallCount = 0

    func searchRepositories(query: String, page: Int) async throws -> SearchRepositoriesResult {
        searchCallCount += 1
        recordedQueries.append(query)
        guard let handler = searchRepositoriesHandler else {
            return SearchRepositoriesResult(totalCount: 0, incompleteResults: false, items: [])
        }
        return try await handler(query, page)
    }

    func releases(owner: String, repo: String) async throws -> [Release] {
        releasesCallCount += 1
        guard let handler = releasesHandler else { return [] }
        return try await handler(owner, repo)
    }

    func readme(owner: String, repo: String) async throws -> String? {
        readmeCallCount += 1
        guard let handler = readmeHandler else { return nil }
        return try await handler(owner, repo)
    }

    func authenticatedUser() async throws -> GitHubUser {
        throw GitHubClientError.unauthenticated
    }

    func setSearchRepositoriesHandler(
        _ handler: @escaping @Sendable (String, Int) async throws -> SearchRepositoriesResult
    ) {
        searchRepositoriesHandler = handler
    }

    func setReleasesHandler(_ handler: @escaping @Sendable (String, String) async throws -> [Release]) {
        releasesHandler = handler
    }

    func setReadmeHandler(_ handler: @escaping @Sendable (String, String) async throws -> String?) {
        readmeHandler = handler
    }
}
