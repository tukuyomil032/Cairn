import Foundation

/// GitHub REST APIクライアント。search/releases/readme/userの4エンドポイントを提供する。
///
/// 未認証でもブラウズ操作が成立する設計（`docs/`外の実装計画セクション2参照）だが、
/// `accessTokenProvider`にトークンがあれば`Authorization`ヘッダーを付与する。
/// 実際の配線は`AuthenticationState.validAccessToken()`（有効期限切れなら自動でrefreshする）を
/// 渡す形になる。401を受けた場合は`onUnauthorized`を呼び、`AuthenticationState`側の
/// `.tokenInvalid`遷移をトリガーできるようにする。
final class GitHubClient: GitHubClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let rateLimiter: GitHubRateLimiter
    private let decoder: JSONDecoder
    private let accessTokenProvider: @Sendable () async -> String?
    private let onUnauthorized: @Sendable () async -> Void

    init(
        baseURL: URL = URL(string: "https://api.github.com")!,
        session: URLSession = .shared,
        rateLimiter: GitHubRateLimiter = GitHubRateLimiter(),
        accessTokenProvider: @escaping @Sendable () async -> String? = { nil },
        onUnauthorized: @escaping @Sendable () async -> Void = {}
    ) {
        self.baseURL = baseURL
        self.session = session
        self.rateLimiter = rateLimiter
        self.accessTokenProvider = accessTokenProvider
        self.onUnauthorized = onUnauthorized

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func searchRepositories(query: String, page: Int, sort: String?, order: String?) async throws
        -> SearchRepositoriesResult
    {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("search/repositories"), resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if let sort {
            queryItems.append(URLQueryItem(name: "sort", value: sort))
        }
        if let order {
            queryItems.append(URLQueryItem(name: "order", value: order))
        }
        components.queryItems = queryItems
        return try await get(components.url!)
    }

    func releases(owner: String, repo: String) async throws -> [Release] {
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/releases")
        return try await get(url)
    }

    func readme(owner: String, repo: String) async throws -> String? {
        let url = baseURL.appendingPathComponent("repos/\(owner)/\(repo)/readme")
        do {
            let content: ReadmeContent = try await get(url)
            guard content.encoding == "base64",
                let data = Data(base64Encoded: content.content.replacingOccurrences(of: "\n", with: "")),
                let text = String(data: data, encoding: .utf8)
            else {
                return nil
            }
            return text
        } catch GitHubClientError.httpError(statusCode: 404) {
            return nil
        }
    }

    func authenticatedUser() async throws -> GitHubUser {
        guard await accessTokenProvider() != nil else {
            throw GitHubClientError.unauthenticated
        }
        let url = baseURL.appendingPathComponent("user")
        return try await get(url)
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token = await accessTokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        try await rateLimiter.waitIfNeeded()

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubClientError.decodingFailed
        }
        await rateLimiter.update(from: httpResponse)

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            await onUnauthorized()
            throw GitHubClientError.tokenInvalid
        case 403, 429:
            await rateLimiter.recordRateLimited(response: httpResponse)
            throw GitHubClientError.rateLimited
        default:
            throw GitHubClientError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw GitHubClientError.decodingFailed
        }
    }
}

private struct ReadmeContent: Decodable {
    let content: String
    let encoding: String
}
