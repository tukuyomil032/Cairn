import Foundation
import Testing

@testable import Cairn

@Suite("KeychainTokenStoreの保存・読込・削除")
struct KeychainTokenStoreTests {
    private static func makeStore(keychain: InMemoryKeychain = InMemoryKeychain()) -> KeychainTokenStore {
        KeychainTokenStore(keychain: keychain, service: "test.service", account: "test-account")
    }

    @Test("saveしたトークンをloadでそのまま復元できる")
    func saveThenLoadRoundTrips() throws {
        let store = Self.makeStore()
        let token = StoredToken(
            accessToken: "access-1",
            accessTokenExpiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            refreshToken: "refresh-1",
            refreshTokenExpiresAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try store.save(token)
        let loaded = try store.load()

        #expect(loaded == token)
    }

    @Test("何も保存していない状態でloadするとnilを返す")
    func loadReturnsNilWhenEmpty() throws {
        let store = Self.makeStore()

        #expect(try store.load() == nil)
    }

    @Test("既存アイテムに再度saveすると新しい値で上書きされる")
    func saveOverwritesExistingItem() throws {
        let keychain = InMemoryKeychain()
        let store = Self.makeStore(keychain: keychain)
        let first = StoredToken(
            accessToken: "access-1",
            accessTokenExpiresAt: nil,
            refreshToken: nil,
            refreshTokenExpiresAt: nil
        )
        let second = StoredToken(
            accessToken: "access-2",
            accessTokenExpiresAt: nil,
            refreshToken: "refresh-2",
            refreshTokenExpiresAt: nil
        )

        try store.save(first)
        try store.save(second)
        let loaded = try store.load()

        #expect(loaded == second)
    }

    @Test("delete後はloadがnilを返す")
    func deleteThenLoadReturnsNil() throws {
        let store = Self.makeStore()
        let token = StoredToken(
            accessToken: "access-1",
            accessTokenExpiresAt: nil,
            refreshToken: nil,
            refreshTokenExpiresAt: nil
        )

        try store.save(token)
        try store.delete()

        #expect(try store.load() == nil)
    }

    @Test("何も保存していない状態でdeleteしてもエラーにならない")
    func deleteWhenEmptyDoesNotThrow() throws {
        let store = Self.makeStore()

        #expect(throws: Never.self) {
            try store.delete()
        }
    }
}
