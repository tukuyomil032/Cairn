/// GitHub Search API向けクエリ構築の共通ロジック。`SearchViewModel`（ユーザー入力起因の検索）と
/// `CacheRefreshScheduler`（起動時の前回トップカテゴリ検索）の両方から使われるため、
/// ジェネリックな`SearchViewModel<ClockType>`に紐付けない独立した型として切り出す。
enum GitHubSearchQueryBuilder {
    /// Swift/Objective-C/Objective-C++製リポジトリのみに絞り込む固定条件。
    static let languageFilter = #"language:Swift OR language:"Objective-C" OR language:"Objective-C++""#

    static func build(from userInput: String) -> String {
        // GitHub Search APIはANDがORより優先順位が高いため、括弧なしだと
        // `userInput AND language:Swift) OR language:"Objective-C" OR language:"Objective-C++"`
        // と解釈され、2つ目・3つ目のOR節でuserInputが完全に無視されてしまう
        // （検索語と無関係なObjective-C/Objective-C++全リポジトリがヒットしていた）。
        // 言語条件全体を括弧で囲むことで意図通りAND(OR OR OR)にする。
        "\(userInput) (\(languageFilter))"
    }
}
