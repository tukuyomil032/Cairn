import Foundation
import Testing

@testable import Cairn

@Suite("カテゴリ分類")
struct CategoryClassifierTests {
    private func makeRepository(
        name: String = "SampleApp",
        topics: [String] = []
    ) -> Repository {
        Repository(
            id: 1,
            name: name,
            fullName: "owner/\(name)",
            owner: GitHubUser(
                id: 1,
                login: "owner",
                avatarURL: URL(string: "https://example.com/avatar.png")!,
                htmlURL: URL(string: "https://github.com/owner")!,
                type: "User"
            ),
            htmlURL: URL(string: "https://github.com/owner/\(name)")!,
            description: nil,
            stargazersCount: 0,
            topics: topics,
            language: "Swift",
            updatedAt: Date(timeIntervalSince1970: 0),
            pushedAt: Date(timeIntervalSince1970: 0),
            defaultBranch: "main",
            archived: false,
            fork: false
        )
    }

    private func makeFixtureKeywords() -> CategoryKeywords {
        CategoryKeywords(keywordsByCategory: [
            .developerTools: ["cli"],
            .productivity: ["todo"],
            .education: ["study"],
        ])
    }

    @Test("topics完全一致が名前・README一致より優先される")
    func topicsMatchOutranksOthers() {
        let classifier = CategoryClassifier(keywords: makeFixtureKeywords())
        let repository = makeRepository(name: "TodoMaster", topics: ["cli"])
        let readme = String(repeating: "x", count: 100) + " study guide"

        let result = classifier.classify(repository: repository, readme: readme)

        #expect(result.category == .developerTools)
    }

    @Test("topics一致がなければリポジトリ名の部分一致が採用される")
    func fallsBackToNameMatch() {
        let classifier = CategoryClassifier(keywords: makeFixtureKeywords())
        let repository = makeRepository(name: "MyTodoApp", topics: [])

        let result = classifier.classify(repository: repository, readme: nil)

        #expect(result.category == .productivity)
    }

    @Test("topics・名前一致がなければREADME冒頭一致が採用される")
    func fallsBackToReadmePrefixMatch() {
        let classifier = CategoryClassifier(keywords: makeFixtureKeywords())
        let repository = makeRepository(name: "SampleApp", topics: [])
        let readme = "A great app for study sessions."

        let result = classifier.classify(repository: repository, readme: readme)

        #expect(result.category == .education)
    }

    @Test("README冒頭範囲(先頭500文字)より後のキーワードは無視される")
    func ignoresKeywordsBeyondReadmePrefix() {
        let classifier = CategoryClassifier(keywords: makeFixtureKeywords())
        let repository = makeRepository(name: "SampleApp", topics: [])
        let readme = String(repeating: "x", count: 500) + "study"

        let result = classifier.classify(repository: repository, readme: readme)

        #expect(result.category == .other)
    }

    @Test("全カテゴリ0点なら other になり、subTagsに元のtopicsがそのまま入る")
    func fallsBackToOtherWithSubTags() {
        let classifier = CategoryClassifier(keywords: makeFixtureKeywords())
        let repository = makeRepository(name: "Unrelated", topics: ["design-tool"])

        let result = classifier.classify(repository: repository, readme: nil)

        #expect(result.category == .other)
        #expect(result.subTags == ["design-tool"])
    }

    @Test("同点スコア時はCategory.allCases宣言順で先に出現するカテゴリが採用される")
    func tieBreaksByDeclarationOrder() {
        let classifier = CategoryClassifier(keywords: makeFixtureKeywords())
        // "cli"(developerTools)と"todo"(productivity)がどちらもtopics完全一致で3点のタイ。
        // Category.allCasesの宣言順ではdeveloperToolsがproductivityより先。
        let repository = makeRepository(name: "SampleApp", topics: ["cli", "todo"])

        let result = classifier.classify(repository: repository, readme: nil)

        #expect(result.category == .developerTools)
    }

    @Test("READMEがnilでもクラッシュせずtopics/名前のみでスコアリングされる")
    func handlesNilReadmeGracefully() {
        let classifier = CategoryClassifier(keywords: makeFixtureKeywords())
        let repository = makeRepository(name: "MyTodoApp", topics: [])

        let result = classifier.classify(repository: repository, readme: nil)

        #expect(result.category == .productivity)
    }

    @Test("topics/name/readme直接指定のオーバーロードもRepository経由と同じ結果になる")
    func directOverloadMatchesRepositoryBasedClassification() {
        let classifier = CategoryClassifier(keywords: makeFixtureKeywords())

        let result = classifier.classify(topics: ["cli"], name: "TodoMaster", readme: nil)

        #expect(result.category == .developerTools)
        #expect(result.subTags == ["cli"])
    }

    @Test("実運用のCategoryKeywords.jsonがバンドルから正しく読み込める")
    func loadsBundledKeywordsWithoutCrashing() {
        let keywords = CategoryKeywords.loadBundled()

        #expect(!(keywords.keywordsByCategory[.developerTools] ?? []).isEmpty)
    }
}
