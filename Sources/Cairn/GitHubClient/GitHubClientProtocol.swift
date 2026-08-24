import Foundation

/// GitHub REST APIへのアクセスを抽象化するプロトコル。
///
/// テスト時にネットワークを叩かないモック実装へ差し替えられるようにするため、
/// `GitHubClient`本体はこのプロトコルの背後に隠す。
protocol GitHubClientProtocol: Sendable {
    /// リポジトリを検索する。`query`はGitHub Search API構文（`language:Swift`等）をそのまま渡す。
    /// `sort`/`order`はGitHub REST APIの同名クエリパラメータ（例: `sort: "stars", order: "desc"`）。
    /// `nil`を渡すとAPIのデフォルト（最適一致順）になる。
    func searchRepositories(query: String, page: Int, sort: String?, order: String?) async throws
        -> SearchRepositoriesResult

    /// 指定リポジトリのReleases一覧を取得する（新しい順）。
    func releases(owner: String, repo: String) async throws -> [Release]

    /// 指定リポジトリのREADME本文を取得する。README未登録の場合は`nil`を返す。
    func readme(owner: String, repo: String) async throws -> String?

    /// 現在認証中のユーザー情報を取得する。未認証の場合は`GitHubClientError.unauthenticated`を投げる。
    func authenticatedUser() async throws -> GitHubUser
}

extension GitHubClientProtocol {
    /// sort/orderを指定しない従来通りの呼び出し（最適一致順）。既存呼び出し元との互換用。
    func searchRepositories(query: String, page: Int) async throws -> SearchRepositoriesResult {
        try await searchRepositories(query: query, page: page, sort: nil, order: nil)
    }
}

/// `GET /search/repositories`のレスポンス全体を表す。
struct SearchRepositoriesResult: Codable, Sendable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [Repository]

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
    }
}

enum GitHubClientError: Error, Equatable {
    /// 認証が必要なエンドポイントに未認証で呼び出した場合。
    case unauthenticated
    /// トークンが無効（失効・取り消し等）で401を受けた場合。
    case tokenInvalid
    /// レート制限超過（403/429）で、リクエストがサーバー側で拒否された場合。
    case rateLimited
    /// 上記以外のHTTPエラー。
    case httpError(statusCode: Int)
    /// レスポンスボディのデコードに失敗した場合。
    case decodingFailed
}
