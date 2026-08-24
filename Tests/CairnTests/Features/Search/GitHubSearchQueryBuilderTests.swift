import Testing

@testable import Cairn

@Suite("GitHub検索クエリ構築")
struct GitHubSearchQueryBuilderTests {
    @Test("言語条件全体が括弧で囲まれ、ユーザー入力がAND(OR OR OR)全体に効く形になる")
    func wrapsLanguageFilterInParentheses() {
        let query = GitHubSearchQueryBuilder.build(from: "claude")

        // 括弧なしだと `claude AND language:Swift) OR language:"Objective-C" OR language:"Objective-C++"`
        // と解釈され、2つ目・3つ目のOR節でuserInputが無視されてしまう
        // （GitHub Search APIはANDがORより優先順位が高いため）。括弧で囲むことで
        // `claude AND (language:Swift OR language:"Objective-C" OR language:"Objective-C++")` になる。
        #expect(query == "claude (language:Swift OR language:\"Objective-C\" OR language:\"Objective-C++\")")
    }

    @Test("ユーザー入力が空でも括弧付きの言語条件が維持される")
    func handlesEmptyInput() {
        let query = GitHubSearchQueryBuilder.build(from: "")
        #expect(query.hasSuffix("(language:Swift OR language:\"Objective-C\" OR language:\"Objective-C++\")"))
    }
}
