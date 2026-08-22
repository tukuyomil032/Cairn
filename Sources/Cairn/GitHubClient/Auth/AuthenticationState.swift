import Foundation
import Observation

enum AuthenticationStatus: Equatable, Sendable {
    /// 未認証。ブラウズ操作は可能（Discovery重視のコアバリューを尊重する設計）。
    case unauthenticated
    /// Device Flow実行中。UIにuser_codeを表示しポーリングしている状態。
    case authenticating(userCode: String, verificationURI: URL)
    /// 認証済み。Keychainに有効なトークンがある。
    case authenticated
    /// トークンが無効化された（401受信、失効等）。再認証を促す。
    case tokenInvalid
}

/// アプリ全体のGitHub認証状態を管理する。起動時にKeychainからトークンを復元し、
/// Device Flowによるサインイン、401受信時の`.tokenInvalid`遷移、サインアウトを扱う。
///
/// SwiftUIビューから直接バインドされるUI状態であるため`@MainActor`に隔離する
/// （`GitHubClient`からは`accessTokenProvider`/`onUnauthorized`クロージャ越しに
/// `await`で呼ばれる想定）。
@Observable
@MainActor
final class AuthenticationState {
    private(set) var status: AuthenticationStatus

    private let tokenStore: KeychainTokenStore
    private let authenticator: DeviceFlowAuthenticator
    private let now: @Sendable () -> Date

    init(
        tokenStore: KeychainTokenStore = KeychainTokenStore(),
        authenticator: DeviceFlowAuthenticator = DeviceFlowAuthenticator(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.tokenStore = tokenStore
        self.authenticator = authenticator
        self.now = now
        self.status = (try? tokenStore.load()) != nil ? .authenticated : .unauthenticated
    }

    /// Device Flowを開始し、成功するまで（またはエラーが起きるまで）実行し続ける。
    /// user_codeが用意でき次第`status`が`.authenticating`へ遷移するので、ブラウザ起動・
    /// クリップボードコピー等のUI側副作用はその状態変化を監視して行う
    /// （`DeviceFlowSignInView`参照。クロージャで直接渡さないのは、Swift 6の厳格な並行性チェック下で
    /// MainActor隔離のUIクロージャを非隔離のasyncメソッドへ渡すのを避けるため）。
    /// `sleep`はテスト時にポーリング間隔の実待機をスキップするための注入ポイント。
    func signIn(
        sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) async throws {
        let deviceCode = try await authenticator.requestDeviceCode()
        status = .authenticating(userCode: deviceCode.userCode, verificationURI: deviceCode.verificationURI)

        do {
            let token = try await authenticator.pollForAccessToken(
                deviceCode: deviceCode.deviceCode,
                interval: deviceCode.interval,
                expiresIn: deviceCode.expiresIn,
                sleep: sleep
            )
            try persist(token)
            status = .authenticated
        } catch {
            status = .unauthenticated
            throw error
        }
    }

    /// 現在のアクセストークン。未認証・失効時は`nil`。有効期限のチェックや自動更新は行わない
    /// 同期アクセサ（UI表示用）。`GitHubClient`からの実際のリクエストには`validAccessToken()`を使う。
    var currentAccessToken: String? {
        (try? tokenStore.load())?.accessToken
    }

    /// 有効なアクセストークンを返す。保存済みトークンが期限切れの場合はrefresh_tokenで自動更新を試み、
    /// 更新後のトークンを返す。未認証・refresh失敗・refresh_token自体の失効時は`nil`を返し、
    /// 後者2つの場合は`.tokenInvalid`へ遷移させて再認証を促す。`GitHubClient`の`accessTokenProvider`に配線する。
    func validAccessToken() async -> String? {
        guard let stored = try? tokenStore.load() else { return nil }

        guard let accessTokenExpiresAt = stored.accessTokenExpiresAt, accessTokenExpiresAt <= now() else {
            return stored.accessToken
        }

        guard let refreshToken = stored.refreshToken,
            stored.refreshTokenExpiresAt.map({ $0 > now() }) ?? true
        else {
            status = .tokenInvalid
            return nil
        }

        do {
            let refreshed = try await authenticator.refreshAccessToken(refreshToken: refreshToken)
            try persist(refreshed)
            status = .authenticated
            return refreshed.accessToken
        } catch {
            status = .tokenInvalid
            return nil
        }
    }

    /// `GitHubClient`が401を受けた際に呼び、再認証を促す状態へ遷移させる。
    func handleUnauthorizedResponse() {
        status = .tokenInvalid
    }

    func signOut() {
        try? tokenStore.delete()
        status = .unauthenticated
    }

    private func persist(_ token: AccessTokenResponse) throws {
        let currentDate = now()
        let stored = StoredToken(
            accessToken: token.accessToken,
            accessTokenExpiresAt: token.expiresIn.map { currentDate.addingTimeInterval(TimeInterval($0)) },
            refreshToken: token.refreshToken,
            refreshTokenExpiresAt: token.refreshTokenExpiresIn.map { currentDate.addingTimeInterval(TimeInterval($0)) }
        )
        try tokenStore.save(stored)
    }
}
