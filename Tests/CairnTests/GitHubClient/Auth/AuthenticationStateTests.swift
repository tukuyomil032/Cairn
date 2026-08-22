import Foundation
import Testing

@testable import Cairn

@Suite("AuthenticationStateの状態遷移", .serialized)
struct AuthenticationStateTests {
    private static func makeAuthenticatorSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [AuthenticationStateStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func makeAuthenticator() -> DeviceFlowAuthenticator {
        DeviceFlowAuthenticator(
            clientID: "test-client-id",
            session: makeAuthenticatorSession(),
            baseURL: URL(string: "https://github.com")!
        )
    }

    private static func stubSuccessfulDeviceFlow() {
        AuthenticationStateStubURLProtocol.stub(
            path: "/login/device/code",
            body: Data(
                """
                {
                    "device_code": "device-abc",
                    "user_code": "ABCD-1234",
                    "verification_uri": "https://github.com/login/device",
                    "expires_in": 899,
                    "interval": 5
                }
                """.utf8
            )
        )
        AuthenticationStateStubURLProtocol.stub(
            path: "/login/oauth/access_token",
            body: Data(
                """
                {
                    "access_token": "issued-token",
                    "expires_in": 28800,
                    "refresh_token": "issued-refresh-token",
                    "refresh_token_expires_in": 15897600,
                    "token_type": "bearer",
                    "scope": ""
                }
                """.utf8
            )
        )
    }

    @Test("Keychainにトークンが無ければ起動時はunauthenticated")
    func startsUnauthenticatedWhenKeychainEmpty() {
        let tokenStore = KeychainTokenStore(keychain: InMemoryKeychain(), service: "svc", account: "acct")
        let state = AuthenticationState(tokenStore: tokenStore, authenticator: Self.makeAuthenticator())

        #expect(state.status == .unauthenticated)
    }

    @Test("Keychainに既存トークンがあれば起動時にauthenticatedへ復元される")
    func restoresAuthenticatedWhenKeychainHasToken() throws {
        let keychain = InMemoryKeychain()
        let tokenStore = KeychainTokenStore(keychain: keychain, service: "svc", account: "acct")
        try tokenStore.save(
            StoredToken(
                accessToken: "existing", accessTokenExpiresAt: nil, refreshToken: nil, refreshTokenExpiresAt: nil)
        )

        let state = AuthenticationState(tokenStore: tokenStore, authenticator: Self.makeAuthenticator())

        #expect(state.status == .authenticated)
        #expect(state.currentAccessToken == "existing")
    }

    @Test("signInが成功するとauthenticatedへ遷移しKeychainへ永続化される")
    func signInSuccessPersistsTokenAndTransitionsToAuthenticated() async throws {
        AuthenticationStateStubURLProtocol.reset()
        Self.stubSuccessfulDeviceFlow()
        let keychain = InMemoryKeychain()
        let tokenStore = KeychainTokenStore(keychain: keychain, service: "svc", account: "acct")
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let state = AuthenticationState(
            tokenStore: tokenStore,
            authenticator: Self.makeAuthenticator(),
            now: { referenceDate }
        )

        var deviceCodeSeen: DeviceCodeResponse?
        try await state.signIn(onDeviceCodeReady: { deviceCodeSeen = $0 }, sleep: { _ in })

        #expect(state.status == .authenticated)
        #expect(state.currentAccessToken == "issued-token")
        #expect(deviceCodeSeen?.userCode == "ABCD-1234")

        let stored = try tokenStore.load()
        #expect(stored?.refreshToken == "issued-refresh-token")
        #expect(stored?.accessTokenExpiresAt == referenceDate.addingTimeInterval(28800))
    }

    @Test("signInがaccess_deniedで失敗するとunauthenticatedに戻り、エラーを投げる")
    func signInFailurePropagatesErrorAndResetsToUnauthenticated() async throws {
        AuthenticationStateStubURLProtocol.reset()
        AuthenticationStateStubURLProtocol.stub(
            path: "/login/device/code",
            body: Data(
                """
                {
                    "device_code": "device-abc",
                    "user_code": "ABCD-1234",
                    "verification_uri": "https://github.com/login/device",
                    "expires_in": 899,
                    "interval": 5
                }
                """.utf8
            )
        )
        AuthenticationStateStubURLProtocol.stub(
            path: "/login/oauth/access_token",
            body: Data("{\"error\": \"access_denied\"}".utf8)
        )
        let tokenStore = KeychainTokenStore(keychain: InMemoryKeychain(), service: "svc", account: "acct")
        let state = AuthenticationState(tokenStore: tokenStore, authenticator: Self.makeAuthenticator())

        await #expect(throws: AuthenticationError.accessDenied) {
            try await state.signIn(sleep: { _ in })
        }
        #expect(state.status == .unauthenticated)
    }

    @Test("handleUnauthorizedResponseを呼ぶとtokenInvalidへ遷移する")
    func handleUnauthorizedResponseTransitionsToTokenInvalid() throws {
        let keychain = InMemoryKeychain()
        let tokenStore = KeychainTokenStore(keychain: keychain, service: "svc", account: "acct")
        try tokenStore.save(
            StoredToken(
                accessToken: "existing", accessTokenExpiresAt: nil, refreshToken: nil, refreshTokenExpiresAt: nil)
        )
        let state = AuthenticationState(tokenStore: tokenStore, authenticator: Self.makeAuthenticator())
        #expect(state.status == .authenticated)

        state.handleUnauthorizedResponse()

        #expect(state.status == .tokenInvalid)
    }

    @Test("signOutでKeychainが削除されunauthenticatedに戻る")
    func signOutClearsTokenAndStatus() throws {
        let keychain = InMemoryKeychain()
        let tokenStore = KeychainTokenStore(keychain: keychain, service: "svc", account: "acct")
        try tokenStore.save(
            StoredToken(
                accessToken: "existing", accessTokenExpiresAt: nil, refreshToken: nil, refreshTokenExpiresAt: nil)
        )
        let state = AuthenticationState(tokenStore: tokenStore, authenticator: Self.makeAuthenticator())

        state.signOut()

        #expect(state.status == .unauthenticated)
        #expect(try tokenStore.load() == nil)
    }

    @Test("アクセストークンが未失効ならvalidAccessTokenはリフレッシュせずそのまま返す")
    func validAccessTokenReturnsStoredTokenWhenNotExpired() async throws {
        AuthenticationStateStubURLProtocol.reset()
        let keychain = InMemoryKeychain()
        let tokenStore = KeychainTokenStore(keychain: keychain, service: "svc", account: "acct")
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        try tokenStore.save(
            StoredToken(
                accessToken: "still-valid",
                accessTokenExpiresAt: referenceDate.addingTimeInterval(3600),
                refreshToken: "refresh-token",
                refreshTokenExpiresAt: nil
            )
        )
        let state = AuthenticationState(
            tokenStore: tokenStore,
            authenticator: Self.makeAuthenticator(),
            now: { referenceDate }
        )

        let token = try #require(await state.validAccessToken())

        #expect(token == "still-valid")
        #expect(AuthenticationStateStubURLProtocol.recordedRequests(matching: "/login/oauth/access_token").isEmpty)
    }

    @Test("アクセストークンが失効していればrefresh_tokenで自動更新しKeychainへ保存する")
    func validAccessTokenRefreshesExpiredToken() async throws {
        AuthenticationStateStubURLProtocol.reset()
        AuthenticationStateStubURLProtocol.stub(
            path: "/login/oauth/access_token",
            body: Data(
                """
                {
                    "access_token": "refreshed-token",
                    "expires_in": 28800,
                    "refresh_token": "new-refresh-token",
                    "refresh_token_expires_in": 15897600,
                    "token_type": "bearer",
                    "scope": ""
                }
                """.utf8
            )
        )
        let keychain = InMemoryKeychain()
        let tokenStore = KeychainTokenStore(keychain: keychain, service: "svc", account: "acct")
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        try tokenStore.save(
            StoredToken(
                accessToken: "expired",
                accessTokenExpiresAt: referenceDate.addingTimeInterval(-1),
                refreshToken: "old-refresh-token",
                refreshTokenExpiresAt: referenceDate.addingTimeInterval(3600)
            )
        )
        let state = AuthenticationState(
            tokenStore: tokenStore,
            authenticator: Self.makeAuthenticator(),
            now: { referenceDate }
        )

        let token = try #require(await state.validAccessToken())

        #expect(token == "refreshed-token")
        #expect(state.status == .authenticated)
        #expect(try tokenStore.load()?.refreshToken == "new-refresh-token")
    }

    @Test("refresh_token自体も失効していればtokenInvalidへ遷移しnilを返す")
    func validAccessTokenReturnsNilWhenRefreshTokenAlsoExpired() async throws {
        AuthenticationStateStubURLProtocol.reset()
        let keychain = InMemoryKeychain()
        let tokenStore = KeychainTokenStore(keychain: keychain, service: "svc", account: "acct")
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        try tokenStore.save(
            StoredToken(
                accessToken: "expired",
                accessTokenExpiresAt: referenceDate.addingTimeInterval(-1),
                refreshToken: "old-refresh-token",
                refreshTokenExpiresAt: referenceDate.addingTimeInterval(-1)
            )
        )
        let state = AuthenticationState(
            tokenStore: tokenStore,
            authenticator: Self.makeAuthenticator(),
            now: { referenceDate }
        )

        let token = await state.validAccessToken()

        #expect(token == nil)
        #expect(state.status == .tokenInvalid)
        #expect(AuthenticationStateStubURLProtocol.recordedRequests(matching: "/login/oauth/access_token").isEmpty)
    }

    @Test("refreshAccessToken呼び出しが失敗するとtokenInvalidへ遷移しnilを返す")
    func validAccessTokenReturnsNilWhenRefreshRequestFails() async throws {
        AuthenticationStateStubURLProtocol.reset()
        AuthenticationStateStubURLProtocol.stub(
            path: "/login/oauth/access_token",
            body: Data("{\"error\": \"bad_refresh_token\"}".utf8)
        )
        let keychain = InMemoryKeychain()
        let tokenStore = KeychainTokenStore(keychain: keychain, service: "svc", account: "acct")
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        try tokenStore.save(
            StoredToken(
                accessToken: "expired",
                accessTokenExpiresAt: referenceDate.addingTimeInterval(-1),
                refreshToken: "old-refresh-token",
                refreshTokenExpiresAt: referenceDate.addingTimeInterval(3600)
            )
        )
        let state = AuthenticationState(
            tokenStore: tokenStore,
            authenticator: Self.makeAuthenticator(),
            now: { referenceDate }
        )

        let token = await state.validAccessToken()

        #expect(token == nil)
        #expect(state.status == .tokenInvalid)
    }
}
