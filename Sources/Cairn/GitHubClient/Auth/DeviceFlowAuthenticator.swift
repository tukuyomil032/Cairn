import Foundation

/// GitHub OAuth Device Flowでユーザー認証を行う。
///
/// シーケンス: `requestDeviceCode()`でuser_codeを取得しUIに表示 → ユーザーがブラウザで
/// `verificationURI`にアクセスしuser_codeを入力・認可 → `pollForAccessToken(deviceCode:interval:expiresIn:)`
/// でアクセストークンを取得するまでポーリングする。
struct DeviceFlowAuthenticator: Sendable {
    private let clientID: String
    private let session: URLSession
    private let baseURL: URL

    init(
        clientID: String = GitHubOAuthConfig.clientID,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://github.com")!
    ) {
        self.clientID = clientID
        self.session = session
        self.baseURL = baseURL
    }

    func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("login/device/code"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("client_id=\(clientID)".utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthenticationError.deviceCodeRequestFailed
        }
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AuthenticationError.deviceCodeRequestFailed
        }
        do {
            return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
        } catch {
            throw AuthenticationError.decodingFailed
        }
    }

    /// 成功するまで（もしくは`access_denied`/`expired_token`を受けるまで）ポーリングを続ける。
    /// `sleep`はテスト時に実際の待機をスキップするための注入ポイント。
    func pollForAccessToken(
        deviceCode: String,
        interval: Int,
        expiresIn: Int,
        sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) async throws -> AccessTokenResponse {
        var currentInterval = interval
        var elapsed = 0

        while elapsed < expiresIn {
            try await sleep(.seconds(currentInterval))
            elapsed += currentInterval

            let poll = try await pollOnce(deviceCode: deviceCode)
            switch poll.error {
            case nil:
                guard let accessToken = poll.accessToken, let tokenType = poll.tokenType, let scope = poll.scope
                else {
                    throw AuthenticationError.decodingFailed
                }
                return AccessTokenResponse(
                    accessToken: accessToken,
                    expiresIn: poll.expiresIn,
                    refreshToken: poll.refreshToken,
                    refreshTokenExpiresIn: poll.refreshTokenExpiresIn,
                    tokenType: tokenType,
                    scope: scope
                )
            case "authorization_pending":
                continue
            case "slow_down":
                currentInterval += 5
                continue
            case "access_denied":
                throw AuthenticationError.accessDenied
            case "expired_token":
                throw AuthenticationError.expiredToken
            case .some(let other):
                throw AuthenticationError.unexpectedResponse(errorCode: other)
            }
        }

        throw AuthenticationError.expiredToken
    }

    private func pollOnce(deviceCode: String) async throws -> TokenPollResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("login/oauth/access_token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "device_code": deviceCode,
            "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        ]
        request.httpBody = Data(body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").utf8)

        let data: Data
        do {
            (data, _) = try await session.data(for: request)
        } catch {
            throw AuthenticationError.networkError
        }
        do {
            return try JSONDecoder().decode(TokenPollResponse.self, from: data)
        } catch {
            throw AuthenticationError.decodingFailed
        }
    }
}

struct DeviceCodeResponse: Decodable, Sendable, Equatable {
    let deviceCode: String
    let userCode: String
    let verificationURI: URL
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct AccessTokenResponse: Sendable, Equatable {
    let accessToken: String
    let expiresIn: Int?
    let refreshToken: String?
    let refreshTokenExpiresIn: Int?
    let tokenType: String
    let scope: String
}

/// ポーリングレスポンス（成功時はaccess_token系フィールド、失敗時はerror系フィールドが入る）。
private struct TokenPollResponse: Decodable {
    let accessToken: String?
    let expiresIn: Int?
    let refreshToken: String?
    let refreshTokenExpiresIn: Int?
    let tokenType: String?
    let scope: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case refreshTokenExpiresIn = "refresh_token_expires_in"
        case tokenType = "token_type"
        case scope
        case error
    }
}
