import Testing

@testable import Cairn

@Suite("プロジェクトセットアップの疎通確認")
struct CairnAppTests {
    @Test("Cairnターゲットがビルド・リンクできる")
    func targetLinks() {
        // Package.swift の executableTarget が正しくテストターゲットから
        // import できることだけを確認する（Phase 0時点ではロジック未実装のため）。
        #expect(Bool(true))
    }
}
