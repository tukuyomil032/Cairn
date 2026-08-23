import Testing

@testable import Cairn

@Suite("Category表示ラベル")
struct CategoryDisplayNameTests {
    @Test("全ケースで空でない日本語ラベルを返す", arguments: Category.allCases)
    func returnsNonEmptyLabel(category: Category) {
        #expect(!category.displayName.isEmpty)
    }

    @Test("各ケースが想定した日本語ラベルと一致する")
    func matchesExpectedLabels() {
        #expect(Category.developerTools.displayName == "開発者ツール")
        #expect(Category.productivity.displayName == "生産性")
        #expect(Category.mediaCreation.displayName == "メディア制作")
        #expect(Category.music.displayName == "音楽")
        #expect(Category.photography.displayName == "写真")
        #expect(Category.utilities.displayName == "ユーティリティ")
        #expect(Category.system.displayName == "システム")
        #expect(Category.games.displayName == "ゲーム")
        #expect(Category.communication.displayName == "コミュニケーション")
        #expect(Category.education.displayName == "教育")
        #expect(Category.other.displayName == "その他")
    }
}
