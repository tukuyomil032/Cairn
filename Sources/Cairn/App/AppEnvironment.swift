import Observation
import SwiftData

/// アプリ全体で共有する依存関係を保持するDIコンテナ。
///
/// Phase5時点ではGitHubClientProtocol/AuthenticationState/ModelContainer/LinguistColorsのみを
/// 保持する。Install/Uninstall Service（Phase7/8で実装予定）等、未実装の依存に対するプレースホルダーは
/// 意図的に置かない（使われない抽象化を先回りして作らない）。
///
/// 元は`Cache/CairnEnvironment.swift`としてModelContainerのみを保持していたが、Phase5でこの容器へ
/// GitHubClient/AuthenticationStateの実配線を追加し`App/`へ移動した。
@Observable
@MainActor
final class AppEnvironment {
    let modelContainer: ModelContainer
    let gitHubClient: GitHubClientProtocol
    let authenticationState: AuthenticationState
    let linguistColors: LinguistColors

    /// - Parameters:
    ///   - inMemory: `true`の場合、ディスクへ永続化しないインメモリコンテナを生成する（テスト用）。
    ///     本番の通常起動では`false`（デフォルト）を使う。
    ///   - gitHubClient: テスト時にモックへ差し替えるためのオーバーライド。`nil`なら本番用`GitHubClient`を生成する。
    ///   - authenticationState: テスト時にオーバーライドするための引数。`nil`なら新規生成する。
    init(
        inMemory: Bool = false,
        gitHubClient: GitHubClientProtocol? = nil,
        authenticationState: AuthenticationState? = nil
    ) {
        let schema = Schema([
            CachedRepository.self,
            CachedRelease.self,
            InstalledApp.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainerの初期化に失敗しました: \(error)")
        }

        let resolvedAuthenticationState = authenticationState ?? AuthenticationState()
        self.authenticationState = resolvedAuthenticationState
        self.gitHubClient =
            gitHubClient
            ?? GitHubClient(
                accessTokenProvider: { await resolvedAuthenticationState.validAccessToken() },
                onUnauthorized: { await resolvedAuthenticationState.handleUnauthorizedResponse() }
            )
        self.linguistColors = .loadBundled()
    }
}
