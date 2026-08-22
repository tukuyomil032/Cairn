import Foundation
import Security

/// Keychainに保存するトークンのペイロード。
struct StoredToken: Codable, Sendable, Equatable {
    let accessToken: String
    let accessTokenExpiresAt: Date?
    let refreshToken: String?
    let refreshTokenExpiresAt: Date?
}

/// 実際のSecItem呼び出しを抽象化するプロトコル。
/// `KeychainTokenStore`をテストする際に、実機のKeychainに触れないフェイク実装へ差し替えるために存在する。
protocol KeychainStoring: Sendable {
    func save(_ data: Data, service: String, account: String) throws
    func load(service: String, account: String) throws -> Data?
    func delete(service: String, account: String) throws
}

enum KeychainError: Error, Equatable {
    case unhandledStatus(OSStatus)
}

/// 実際のmacOS KeychainへSecItem APIで読み書きする実装。
/// 端末ローカルのみ（`kSecAttrSynchronizable = false`）、`kSecAttrAccessibleAfterFirstUnlock`。
struct SystemKeychain: KeychainStoring {
    func save(_ data: Data, service: String, account: String) throws {
        let query = Self.baseQuery(service: service, account: account)
        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            addQuery[kSecAttrSynchronizable as String] = false
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandledStatus(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandledStatus(updateStatus)
        }
    }

    func load(service: String, account: String) throws -> Data? {
        var query = Self.baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
        return result as? Data
    }

    func delete(service: String, account: String) throws {
        let query = Self.baseQuery(service: service, account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// GitHub OAuthのアクセストークン/リフレッシュトークンをKeychainへ保存・読込・削除する。
struct KeychainTokenStore: Sendable {
    private let keychain: KeychainStoring
    private let service: String
    private let account: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        keychain: KeychainStoring = SystemKeychain(),
        service: String = "com.tukuyomil032.cairn",
        account: String = "github-oauth-token"
    ) {
        self.keychain = keychain
        self.service = service
        self.account = account

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func save(_ token: StoredToken) throws {
        let data = try encoder.encode(token)
        try keychain.save(data, service: service, account: account)
    }

    func load() throws -> StoredToken? {
        guard let data = try keychain.load(service: service, account: account) else { return nil }
        return try decoder.decode(StoredToken.self, from: data)
    }

    func delete() throws {
        try keychain.delete(service: service, account: account)
    }
}
