/// GitHub App（"Cairn Auth Connecter"）のOAuth Device Flow用設定。
///
/// Client IDはClient Secret不要のPublic Client方式（Device Flow）のため、
/// アプリバイナリに定数として埋め込む（`gh` CLI等と同じ方式）。
enum GitHubOAuthConfig {
    static let clientID = "Iv23liCRmDL32QCNMQ29"
}
