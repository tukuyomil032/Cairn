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
@Observable
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
    /// `onDeviceCodeReady`はuser_code表示直後（ブラウザ起動・クリップボードコピー等をUI側で行うため）に呼ばれる。
    /// `sleep`はテスト時にポーリング間隔の実待機をスキップするための注入ポイント。
    func signIn(
        onDeviceCodeReady: (DeviceCodeResponse) -> Void = { _ in },
        sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) async throws {
        let deviceCode = try await authenticator.requestDeviceCode()
        status = .authenticating(userCode: deviceCode.userCode, verificationURI: deviceCode.verificationURI)
        onDeviceCodeReady(deviceCode)

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

    /// 現在のアクセストークン。未認証・失効時は`nil`。`GitHubClient`の`accessTokenProvider`に配線する。
    var currentAccessToken: String? {
        (try? tokenStore.load())?.accessToken
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
