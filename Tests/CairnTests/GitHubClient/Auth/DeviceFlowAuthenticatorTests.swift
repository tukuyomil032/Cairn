import Foundation
import Testing

@testable import Cairn

/// `pollForAccessToken`に注入したsleepクロージャの呼び出し履歴を記録するテスト用ヘルパー。
private actor SleepRecorder {
    private(set) var durations: [Duration] = []

    func record(_ duration: Duration) {
        durations.append(duration)
    }
}

@Suite("DeviceFlowAuthenticatorのポーリング挙動", .serialized)
struct DeviceFlowAuthenticatorTests {
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DeviceFlowStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func makeAuthenticator() -> DeviceFlowAuthenticator {
        DeviceFlowAuthenticator(
            clientID: "test-client-id",
            session: makeSession(),
            baseURL: URL(string: "https://github.com")!
        )
    }

    private static func pollBody(error: String? = nil, accessToken: String? = nil) -> Data {
        if let error {
            return Data("{\"error\": \"\(error)\"}".utf8)
        }
        return Data(
            """
            {
                "access_token": "\(accessToken ?? "token")",
                "expires_in": 28800,
                "refresh_token": "refresh-token",
                "refresh_token_expires_in": 15897600,
                "token_type": "bearer",
                "scope": ""
            }
            """.utf8
        )
    }

    @Test("requestDeviceCodeがdevice_code/user_codeをデコードする")
    func requestDeviceCodeDecodesResponse() async throws {
        DeviceFlowStubURLProtocol.reset()
        let body = """
            {
                "device_code": "device-abc",
                "user_code": "ABCD-1234",
                "verification_uri": "https://github.com/login/device",
                "expires_in": 899,
                "interval": 5
            }
            """
        DeviceFlowStubURLProtocol.stub(path: "/login/device/code", body: Data(body.utf8))

        let authenticator = Self.makeAuthenticator()
        let response = try await authenticator.requestDeviceCode()

        #expect(response.deviceCode == "device-abc")
        #expect(response.userCode == "ABCD-1234")
        #expect(response.interval == 5)
    }

    @Test("requestDeviceCodeが非200レスポンスだとdeviceCodeRequestFailedを投げる")
    func requestDeviceCodeThrowsOnFailure() async throws {
        DeviceFlowStubURLProtocol.reset()
        DeviceFlowStubURLProtocol.stub(path: "/login/device/code", statusCode: 500, body: Data())

        let authenticator = Self.makeAuthenticator()

        await #expect(throws: AuthenticationError.deviceCodeRequestFailed) {
            try await authenticator.requestDeviceCode()
        }
    }

    @Test("authorization_pendingが2回続いた後successすればトークンを返す")
    func pollSucceedsAfterPendingResponses() async throws {
        DeviceFlowStubURLProtocol.reset()
        DeviceFlowStubURLProtocol.stub(
            path: "/login/oauth/access_token",
            sequence: [
                DeviceFlowStubURLProtocol.Stub(
                    statusCode: 200, headers: [:], body: Self.pollBody(error: "authorization_pending")),
                DeviceFlowStubURLProtocol.Stub(
                    statusCode: 200, headers: [:], body: Self.pollBody(error: "authorization_pending")),
                DeviceFlowStubURLProtocol.Stub(
                    statusCode: 200, headers: [:], body: Self.pollBody(accessToken: "final-token")),
            ]
        )

        let authenticator = Self.makeAuthenticator()
        let recorder = SleepRecorder()
        let token = try await authenticator.pollForAccessToken(
            deviceCode: "device-abc",
            interval: 5,
            expiresIn: 900,
            sleep: { duration in await recorder.record(duration) }
        )

        #expect(token.accessToken == "final-token")
        #expect(token.refreshToken == "refresh-token")
        #expect(await recorder.durations == [.seconds(5), .seconds(5), .seconds(5)])
    }

    @Test("slow_downを受けるとintervalを5秒増やして待機する")
    func pollIncreasesIntervalOnSlowDown() async throws {
        DeviceFlowStubURLProtocol.reset()
        DeviceFlowStubURLProtocol.stub(
            path: "/login/oauth/access_token",
            sequence: [
                DeviceFlowStubURLProtocol.Stub(statusCode: 200, headers: [:], body: Self.pollBody(error: "slow_down")),
                DeviceFlowStubURLProtocol.Stub(
                    statusCode: 200, headers: [:], body: Self.pollBody(accessToken: "final-token")),
            ]
        )

        let authenticator = Self.makeAuthenticator()
        let recorder = SleepRecorder()
        _ = try await authenticator.pollForAccessToken(
            deviceCode: "device-abc",
            interval: 5,
            expiresIn: 900,
            sleep: { duration in await recorder.record(duration) }
        )

        // 1回目は元のinterval(5秒)で待機してslow_downを受け、2回目は+5秒された10秒で待機してから成功する。
        #expect(await recorder.durations == [.seconds(5), .seconds(10)])
    }

    @Test("access_deniedを受けるとaccessDeniedを投げる")
    func pollThrowsAccessDenied() async throws {
        DeviceFlowStubURLProtocol.reset()
        DeviceFlowStubURLProtocol.stub(path: "/login/oauth/access_token", body: Self.pollBody(error: "access_denied"))

        let authenticator = Self.makeAuthenticator()

        await #expect(throws: AuthenticationError.accessDenied) {
            try await authenticator.pollForAccessToken(
                deviceCode: "device-abc",
                interval: 5,
                expiresIn: 900,
                sleep: { _ in }
            )
        }
    }

    @Test("expired_tokenを受けるとexpiredTokenを投げる")
    func pollThrowsExpiredToken() async throws {
        DeviceFlowStubURLProtocol.reset()
        DeviceFlowStubURLProtocol.stub(path: "/login/oauth/access_token", body: Self.pollBody(error: "expired_token"))

        let authenticator = Self.makeAuthenticator()

        await #expect(throws: AuthenticationError.expiredToken) {
            try await authenticator.pollForAccessToken(
                deviceCode: "device-abc",
                interval: 5,
                expiresIn: 900,
                sleep: { _ in }
            )
        }
    }

    @Test("ネットワーク断（リクエストに対応するスタブなし）だとnetworkErrorを投げる")
    func pollThrowsOnNetworkFailure() async throws {
        DeviceFlowStubURLProtocol.reset()
        // パスに対するスタブを一切登録しないことで、URLProtocolが読み込み失敗を返す状況を再現する。

        let authenticator = Self.makeAuthenticator()

        await #expect(throws: AuthenticationError.networkError) {
            try await authenticator.pollForAccessToken(
                deviceCode: "device-abc",
                interval: 5,
                expiresIn: 900,
                sleep: { _ in }
            )
        }
    }

    @Test("refreshAccessTokenが成功すると新しいトークンを返す")
    func refreshAccessTokenReturnsNewToken() async throws {
        DeviceFlowStubURLProtocol.reset()
        DeviceFlowStubURLProtocol.stub(
            path: "/login/oauth/access_token",
            body: Self.pollBody(accessToken: "refreshed-token")
        )

        let authenticator = Self.makeAuthenticator()
        let token = try await authenticator.refreshAccessToken(refreshToken: "old-refresh-token")

        #expect(token.accessToken == "refreshed-token")
        #expect(token.refreshToken == "refresh-token")
    }

    @Test("refreshAccessTokenがエラーレスポンスを受けるとunexpectedResponseを投げる")
    func refreshAccessTokenThrowsOnErrorResponse() async throws {
        DeviceFlowStubURLProtocol.reset()
        DeviceFlowStubURLProtocol.stub(
            path: "/login/oauth/access_token",
            body: Self.pollBody(error: "bad_refresh_token")
        )

        let authenticator = Self.makeAuthenticator()

        await #expect(throws: AuthenticationError.unexpectedResponse(errorCode: "bad_refresh_token")) {
            try await authenticator.refreshAccessToken(refreshToken: "old-refresh-token")
        }
    }
}
