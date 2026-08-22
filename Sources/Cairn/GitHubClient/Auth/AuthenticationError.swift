import Foundation

enum AuthenticationError: Error, Equatable, Sendable {
    /// `/login/device/code`の呼び出し自体が失敗した（ネットワークエラー、非2xxレスポンス等）。
    case deviceCodeRequestFailed
    /// ユーザーがGitHub上で認可を拒否した。
    case accessDenied
    /// device_codeの有効期限が切れた（`expires_in`超過）。ユーザーに再試行を促す。
    case expiredToken
    /// GitHubから想定外のエラーコードが返された。
    case unexpectedResponse(errorCode: String)
    /// レスポンスボディのデコードに失敗した。
    case decodingFailed
    /// リクエスト自体が失敗した（接続不可、タイムアウト等）。
    case networkError
}
