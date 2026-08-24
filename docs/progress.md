# 実装進捗

実装計画の全文は `docs/` 外の Claude Code プランファイルにある。このファイルはフェーズ単位の完了状況を追跡するための簡易チェックリスト。

## Phase 0: プロジェクトセットアップ — 完了

- [x] `Package.swift`のみでプロジェクト作成（`.xcodeproj`なし）
- [x] SPM依存4種追加（Sparkle, ZIPFoundation, Defaults, Permiso）
- [x] `Info.plist`/`Cairn.entitlements`を`Resources/`に手動配置し、`resources:`から除外（SwiftPMの制約対応）
- [x] `Sources/Cairn`配下のフォルダ構成作成
- [x] `version.env`作成（単一チャンネル方式）
- [x] `docs/dependencies.md`作成

## Phase 0.5: 開発ツールチェーン整備 — 完了

- [x] `justfile`（setup/build/release/test/format/lint/run/run-release/clean）
- [x] `lefthook.yml`（pre-commitで`swift-format`自動整形→再ステージ→`swiftlint lint`）
- [x] `.swiftlint.yml` / `.swift-format`の最小設定
- [x] `scripts/build.sh` / `scripts/test.sh` / `scripts/run.sh`（`xcbeautify`経由）
  - `xcbeautify`はデフォルトだと`swift build`/`swift test`のシンプルな進捗ログを認識できず出力ごと捨てるため、`--preserve-unbeautified`が必須（要注意点として記録）
  - CI環境（`CI=true`）では`--is-ci --renderer github-actions`を付与
- [x] `.github/workflows/ci.yml`（lint + `scripts/build.sh`）/ `test.yml`（`scripts/test.sh`）: `**/*.swift`が変更されたpush/PRのみトリガー
- [x] `.github/workflows/release.yml`: `workflow_dispatch`のみの手動トリガー、`prerelease: true`固定、xcbeautifyは使わない（素の`swift build -c release`）
- [x] `docs/dependencies.md`から個人の参考プロジェクト名を一般化した表現に匿名化
- [x] `permiso`依存を`branch: "main"`から特定コミットへの`revision:`固定に変更（supply-chain対応）

## Phase 1: GitHub APIクライアント層 + 認証 — 完了

**事前準備（ユーザー作業、実施済み）**: GitHub App「Cairn Auth Connecter」作成（Device Flow有効化、Contents/Metadata読み取り権限、Expire user authorization tokens有効）。Client IDは`GitHubOAuthConfig.swift`に埋め込み。当初はclassic OAuth Appを想定していたが、`Ov23li`プレフィックスのClient IDはトークンが失効しない（refresh_token非対応）ことが判明したため、GitHub Appへ切り替えた。GitHub Appのuser-to-serverトークンが未インストールの公開リポジトリ（`torvalds/linux`等）にも問題なくアクセスできることをcurlで実機検証済み。

- [x] `GitHubModels`定義（`Models/Repository.swift`, `Release.swift`, `GitHubUser.swift`）
- [x] `GitHubRateLimiter`実装
- [x] `GitHubClient`基本実装（search/releases/readme/user）
- [x] `DeviceFlowAuthenticator`実装
- [x] `KeychainTokenStore`実装
- [x] `AuthenticationState`実装（`@MainActor`）
- [x] refresh token自動更新ロジック（`AuthenticationState.validAccessToken()`）
- [x] `GitHubClient`への認証統合（`onUnauthorized`フック。実際のDI配線はUI機能フェーズで）
- [x] `DeviceFlowSignInView`実装（自動テストなし、実機確認が必要）

**既知の未実施事項**: `just run`での実機サインインフロー確認（ユーザー環境でのみ実施可能）。

## Phase 2: 永続化層（SwiftData） — 完了

- [x] `CachedRepository`/`CachedRelease`/`InstalledApp` の `@Model` 定義（`Cache/`配下）
  - `category`はPhase3の`Category` enumへの依存を避け、Phase2では`String`のまま保持
  - `CachedRelease`に`repository`逆参照を追加（元プランのスニペットにはないが、`deleteRule: .cascade`を機能させるために必須）
- [x] `CairnEnvironment`実装（`ModelContainer`保持の軽量環境容器、on-disk/in-memory切り替え、初期化失敗時は`fatalError`）
- [x] `CairnApp.swift`への`.modelContainer(_:)`配線（`just run`で実機起動・永続化ストア生成を確認済み）
- [x] SwiftTestingによるCRUD/cascade削除/unique制約のテスト

**実装時に判明した挙動**: SwiftDataの`@Attribute(.unique)`制約は違反時に例外を投げず、既存レコードを上書き（upsert）する。テストはこの実挙動に合わせて期待値を確定した。また、in-memory `ModelContainer`を返す際は`CairnEnvironment`インスタンス自体を保持し続ける必要がある（`ModelContext`だけを返す一時関数だとコンテナが解放されテストプロセスがクラッシュする）。

**今回のスコープ外（次フェーズへ）**: `GitHubClient`/`AuthenticationState`を含む本格的な`AppEnvironment`へのDI配線は、引き続き「UI機能フェーズ」で行う。

## Phase 3: ノイズ除去 + 分類ロジック — 完了

**判断背景**: ノイズ除去条件は当初「star数の閾値でフィルタ」する案も検討したが、「知る人ぞ知る新規の良質アプリを取りこぼしてしまい、Cairnの『発見重視』というコアバリューと相性が悪い」という理由で不採用にした。代わりに「リポジトリのtopicsタグに`macos`/`macos-app`等が含まれる」と「GitHub Releasesに`.dmg`または`.zip`資産が存在する」の2条件ANDのみを採用する。

ジャンル分類は「固定カテゴリ + キーワードマッピングのハイブリッド」方式。キーワード辞書をSwiftコード内のenumではなく`Resources/CategoryKeywords.json`として外部化するのは、「今後手動でメンテしていく前提」という要件に合わせ、リビルドなしで調整できるようにするため。スコアで一件もマッチしない場合は「その他」に分類しつつ、元のtopicsを常にサブタグとして併記する（両方採用）。これはユーザーに確認したわけではなく、実装計画側の判断——「その他」だけで大量の未分類アプリが並ぶと発見体験が悪化するため、サブタグでの絞り込み・検索を可能にする、という設計意図。

- [x] `NoiseFilter`実装（`requiredTopicsAny`と`validAssetExtensions`のAND条件判定。`.pkg`のみの資産は今回スコープ外、コード上にコメントで将来拡張ポイントを残す）
- [x] `Category` enum定義（developerTools, productivity, mediaCreation, music, photography, utilities, system, games, communication, education, other）
- [x] `Resources/CategoryKeywords.json`初期辞書作成
- [x] `CategoryClassifier`実装（スコアリング: topics完全一致3点 > リポジトリ名部分一致2点 > README冒頭一致1点。最高スコアのカテゴリを採用、全スコア0なら`.other`+元topicsをサブタグ併記）

**該当するデザインパターン**: Strategy（`NoiseFilter`/`CategoryClassifier`を判定ロジックとして差し替え可能にする）

**テスト方針**:
- `NoiseFilterTests`: topics有無×asset有無の4象限を検証
- `CategoryClassifierTests`: topics/名前/README一致の優先順位、フォールバック"other"+サブタグ併記を検証

**実装時に確定した設計判断（要件に数値・範囲の明記がなかった点）**:
- `subTags`は`.other`に限定せず、全カテゴリで一律`repository.topics`を併記する（分類済みアプリでもtopicsベースの絞り込み・検索を可能にするため。ユーザー確認済み）
- README「冒頭」の範囲は先頭500文字と定義（タイトル+概要段落程度をカバーしつつ詳細セクションには踏み込まない目安。ユーザー確認済み）
- スコア同点時のタイブレークは`Category.allCases`の宣言順で最初に最高得点になったカテゴリを採用する決定的ルールとした（`Dictionary`のキー順は不定なため必須の設計）
- Strategyパターンのプロトコル命名は動名詞スタイル（`NoiseFiltering`/`CategoryClassifying`）を採用（ユーザー確認済み。既存コードには名詞+Protocol派もあるため今後混在に注意）

## Phase 4: 検索アーキテクチャ — 未着手

**判断背景（最重要・当初計画からの転換点）**: 当初は「未認証のGitHub Search APIのみでスタートし、トークンバケット式レートリミッター＋バックグラウンドのローリング更新＋同梱シードデータでコールドスタートに対応する」という設計まで一度確定していた（未認証だとSearch 10req/min・Core 60req/hしか使えないため、キャッシュ優先の妥協的な設計が前提だった）。しかしPlan承認の直前になって「認証すればレート制限の枠が広がるなら、普段からAPI検索してその結果をキャッシュに反映すればいいのでは」という方針転換があり、GitHub OAuth Device Flow認証を最初のスコープに含めることが決定した（Phase 1として実装済み。Search 30req/min・Core 5000req/hに拡大）。この転換によって検索方式も「キャッシュ内のみを検索」から「入力に応じてAPI即応検索し、結果をキャッシュへ反映する（stale-while-revalidate）」に変わった。

無駄なAPI呼び出しを避けるため、対象ごとに以下の対策を取る:

| 対象 | 対策 |
|---|---|
| 検索クエリ | デバウンス300ms、直近同一クエリ5秒以内は再送しない |
| Releases確認 | 詳細画面表示時のみ取得、TTL 1時間 |
| README取得 | 詳細画面表示時のみ取得、TTL 24時間。失敗時はtopics/名前のみでフォールバック分類 |
| dmg/zip資産チェック | Releases一覧APIの`assets[].name`を見るだけ（ダウンロードはしない） |

常時のバックグラウンドローリング更新は行わない（認証後はAPIを都度叩けるため必要性が低くなったため）。`CacheRefreshScheduler`は「起動時に前回のトップカテゴリのみ1回軽量更新」「詳細画面の遅延再検証」に縮小する。

- [x] `SearchViewModel`実装（デバウンス300ms、直近同一クエリ5秒以内は再送なし、`language:Swift OR language:"Objective-C" OR language:"Objective-C++"`を1クエリにまとめる、stale-while-revalidate）
- [x] 縮小版`CacheRefreshScheduler`実装（起動時に前回トップカテゴリのみ1回軽量更新、詳細画面の遅延再検証）

**実装時に確定した設計判断（着手前にユーザーへ再確認したもの）**:
- `SearchViewModel`/`CacheRefreshScheduler`ともに`GitHubClientProtocol`/`ModelContext`をinitで直接受け取る疎結合設計とし、`CairnEnvironment`自体はPhase4では拡張しない（本格的なDIコンテナ化はPhase5に持ち越す）
- `CachedRepository`に`lastReadmeFetchedAt: Date?`を追加（README取得TTL 24時間の判定用）
- 前回トップカテゴリは`Defaults`パッケージ（`Package.swift`に導入済みだが本フェーズが初使用）で永続化。Phase4は読み出し専用（`refreshTopCategoryOnLaunch()`）に留め、書き込み側（カテゴリ選択時の更新）はPhase5のDiscovery UIで追加する
- デバウンス300ms・重複クエリ抑制5秒の判定は、Swift標準の`Clock`プロトコルを注入可能にして実待機なしにテストする設計にした（`SearchViewModel`は`ClockType: Clock`のジェネリッククラス、本番は`ContinuousClock`、テストは自作の`ManualClock`）
- **NoiseFilter（dmg/zip資産チェック）は検索結果一覧の段階で適用する**（ユーザーの明示選択）。これは「詳細画面遷移時のみ適用」より無駄なAPI呼び出しが増えるトレードオフ——検索結果1ページ（最大30件）ごとにReleases一覧APIを追加で叩く——を承知の上での判断。アセット本体のダウンロードは発生しない
- README取得が失敗した場合、`lastReadmeFetchedAt`のTTLは更新しない（次回訪問時に再取得を試せるようにするため。既存分類はそのまま維持する）
- `CategoryClassifying`に`classify(topics:name:readme:)`オーバーロードを追加し、`CacheRefreshScheduler`が`CachedRepository`（SwiftDataモデル）から`Repository`（APIレスポンス型）を経由せず再分類できるようにした
- 起動時の軽量更新呼び出しは`CairnEnvironment`を拡張せず、`CairnApp.swift`の`.task`から都度`CacheRefreshScheduler`を生成して呼ぶ最小限の配線に留めた

**テスト方針**: `SearchViewModelTests`（デバウンス・重複抑制・stale-while-revalidateの順序・NoiseFilter除外・Taskキャンセル）、`CacheRefreshSchedulerTests`（前回トップカテゴリ読み出し・未設定時no-op・Releases/README TTL境界・README失敗時のTTL非更新）を追加。時間依存ロジックは`ManualClock`（Clock注入）と固定`now`クロージャで実待機なしに検証している。

## Phase 5: Discovery UI — 完了

**判断背景**: 当初この計画を書いた時点ではユーザーとの直接の壁打ちがほとんどなく、「標準的なmacOSカタログアプリ構造」（`NavigationSplitView`+サイドバー+グリッド一覧）が仮採用されていた。その後、2026年8月に実装着手前のビジュアル壁打ちセッションを別途実施し、`design`スキル（Claude Designキャンバス）でDiscovery/Install/Settings/Library/AppDetail/エラー状態を含む全画面モックアップと、サイドバーのピン留め/解除インタラクションのプロトタイプを作成済みだった。しかし実装フェーズで複数ラウンドの試行錯誤を経て、最終的にはモックアップの独自ピン/ホバー展開インタラクションを撤回し、当初仮採用していた素の`NavigationSplitView`に回帰する形で決着した（詳細は下記「実装時の紆余曲折」参照）。

- [x] `SidebarView`実装（`NavigationSplitView`+`List(selection:)`。全カテゴリ("すべて")/`Category.allCases`（件数バッジ付き）/ライブラリ。「設定」はメニューバー常駐アイコンへ移動したためサイドバーには含めない）
- [x] `CategoryGridView`実装（`LazyVGrid`+`AppCardView`: 名前/star数/言語カラー/サブタグチップ、3Dパララックスホバー付き）
- [x] 検索バー実装（`SearchBarView`という専用Viewは作らず、`.searchable(placement: .toolbar)`で実装。未認証時はツールバーにサインインボタンを表示）
- [x] 言語カラー表示用の`LinguistColors.json`用意（GitHub Linguistの全688言語分を収録）
- [x] `SearchViewModel`/`DiscoveryViewModel`を`@Observable final class`として実装し、`AppEnvironment`（GitHubClient/AuthenticationState/ModelContainer/LinguistColorsを保持。Install/Uninstall Serviceは未実装のためプロパティ自体を持たせていない）から`.environment(_:)`経由で注入する構成にした
- [x] `MenuBarExtra`+`Settings`シーンで「設定」をメニューバー常駐化（本格的な設定項目はPhase11で実装、現状は`SettingsPlaceholderView`というプレースホルダーのみ）

**実装時の紆余曲折（重要な設計判断の記録）**:
1. 当初モックアップ通り、独自`HStack`/`ZStack`構造でXcodeナビゲータ風の「ピン留め解除時、カーソルを左端に寄せるとサイドバーがホバー展開する」インタラクションを実装した。
2. Liquid Glass感を出すため、非公開API`NSGlassEffectView`をランタイム解決する独自ラッパーを実装したが、検索バーが非表示になる・サイドバーがピン留め中だけガラスが消える・ボタンの主張が強すぎる、という不具合を3件連続で起こした。
3. 非公開APIを廃し標準`Material`（`.thickMaterial`）に切り替えたが、サイドバーの選択ハイライトに「立体感がない」という指摘を受けた。
4. MITライセンスの参考ネイティブアプリ2件（`msitarzewski/brew-browser`、`steipete/CodexBar`）を実際に調査した結果、いずれも独自実装を一切持たず、標準`NavigationSplitView`/`List(selection:)`/`.searchable()`だけで見栄えの良いネイティブサイドバーを実現していると判明。「独自実装をできるだけ避け、Apple公式のSwiftUI/AppKit機能を最優先で使う」という原則をCLAUDE.mdに明文化し、Cairnも`NavigationSplitView`へ全面移行した。
5. この移行に伴い、独自のピン/ホバー展開インタラクション仕様は撤回した（`docs/design/sidebar-interaction.md`に撤回経緯を記録済み）。`SidebarState.swift`・`LiquidGlass.swift`・`PressableButtonStyle.swift`・`SearchBarView.swift`は最終的にすべて削除し、標準APIのみの構成に落ち着いた。

**テスト方針**: `Category+DisplayNameTests`、`LinguistColorsTests`、`DiscoveryViewModelTests`（カテゴリフィルタ・件数集計・`lastTopCategory`書き込み）、`ParallaxHoverModifierTests`（座標変換の純粋関数）を実装。View自体（`SidebarView`/`CategoryGridView`/`AppCardView`/`DiscoveryView`）はロジックを持たないため実機確認中心とした。

## Phase 5.5: 検索解像度向上 + プロアクティブなバックグラウンドクロール — 未着手

**判断背景**: Phase5完了後の実機確認中、ユーザーから「Cairnの発見体験の質は、実際にGitHub上で使われているtopicsタグ・キーワードの実態にどれだけ検索条件を合わせられるかに懸かっている」という指摘があった。ユーザー自身のGitHub Starの中にmacOS向けリリースを持つアプリが多数あり、似たジャンルの「競合」アプリ同士でもtopicsタグ・キーワードの付け方が微妙に異なることを実際に把握している。現行の`NoiseFilter.requiredTopicsAny`（`macos`/`macos-app`の2つのみ）や`CategoryKeywords.json`は当て推量で作られており、実態とズレている可能性が高い。

さらに、現行の「ユーザーが検索して初めてSwiftDataキャッシュに載る」というリアクティブなモデル自体への疑義も提起された。「Discovery（発見）」を掲げるアプリが、ユーザーが検索語を知っている前提のUXでは核心的価値と矛盾する。サイドバーの各カテゴリを開いたら、ユーザー自身の検索操作の有無に関わらず最初から様々なアプリが並んでいる、というプロアクティブなモデルの方が優れているという判断で合意した（もちろん手動検索も従来通り併用可能）。

**2段構成の計画（このセッションでは方針決定・文書化のみ。実装はPhase6着手前の別セッションで行う）**:

1. **検索解像度向上のためのデータ収集（Codexへ委譲）**: Cairnの目的・現行の分類設計（`Category` enum、`CategoryKeywords.json`、`NoiseFilter`のtopics/資産要件）をブリーフィングした上で、Codexに「GitHub ReleasesでmacOS向け配布（`.dmg`/`.zip`資産あり）を行っている実在リポジトリを様々なジャンルにわたって約500件調査し、実際に使われているtopicsタグ・キーワードの頻度分布を報告する」というリサーチタスクを委譲する。期待する成果物は`NoiseFilter.requiredTopicsAny`の拡張候補・`CategoryKeywords.json`の拡充候補・現行の固定条件では除外されてしまう実在アプリの具体例。大量リポジトリの機械的調査という性質上、Codexのようなエージェントに向いたタスクと判断した。

2. **プロアクティブなバックグラウンド事前クロール**: 段階1で得た拡充済みキーワード/topics集合を使い、`CacheRefreshScheduler`の役割を「既存キャッシュの鮮度維持」から「新規リポジトリの発見的クロール」まで拡張する。各`Category`について拡充済みキーワードで定期的にGitHub検索を実行し、ヒットしたリポジトリを`NoiseFilter`＋`CategoryClassifier`を通した上でSwiftDataキャッシュへupsertする。**最大の技術的論点はレート制限設計**——GitHub Search APIは認証済みでも30req/minという制約があり（Phase4で確認済み）、全11カテゴリを一度にクロールすることはできない。「起動ごとに1カテゴリだけローテーションでクロールする」「カテゴリごとの最終クロール日時を永続化し一定期間経過したものだけ対象にする」といった段階的スケジューリングの詳細設計は、Phase5.5実装着手時に行う。

Phase5ラウンド7で追加する「トレンド」機能（起動時に1回だけGitHub検索して人気macOSアプリを表示）は、このプロアクティブ事前取得パターンの最小版とみなせる。Phase5.5ではこのパターンをカテゴリ横断・スケジューリング付きで一般化する。

## Phase 6: AppDetail UI — 未着手

**判断背景**: README表示方式は壁打ちセッションでも結論が出ておらず「未解決事項」として持ち越されていた。実装計画では「まず標準API`AttributedString(markdown:)`で開始し、表現力不足が問題になれば`swift-markdown`等の追加を検討する」という段階的方針を採用している。`swift-markdown`のようなSPM追加を検討する際は、Phase10で確立した「基本はApple標準API、ただし広く使われている定番SPMは可」という依存関係採用基準（`docs/dependencies.md`参照）に沿って判断する。加えて、README/説明文をシステム言語が日本語の場合デフォルトで日本語訳表示する機能（Apple Translation framework、オンデバイス）をPhase6のタスクに含める——詳細は`docs/design/localization.md`参照。

- [ ] `AppDetailView`実装（README概要を`AttributedString(markdown:)`標準APIでレンダリング）
- [ ] `AppDetailViewModel`実装
- [ ] インストールボタン押下時、未認証なら`DeviceFlowSignInView`（Phase1で実装済み）をモーダル表示し、認証完了後にインストールフローへ自動復帰する導線を実装

**テスト方針についての注意**: 実装計画にPhase6固有のテスト項目は明記されていない。Phase6着手時に自前で定義する。

## Phase 7: インストール機能 — 未着手

**フロー（Homebrew Caskライクな自動化）**:
```
ダウンロード(.dmg/.zip) → 種別判定
  .dmg → DMGMounter(Process + hdiutil attach -nobrowse -plist)
  .zip → ZipExtractor(ZIPFoundation)
→ .appバンドル検索 → ApplicationsInstaller(/Applicationsへコピー、
  既存同名.app上書き確認) → dmgのunmount/一時ファイル削除(defer) →
  InstalledApp(@Model)に記録 → 完了通知
```

- [ ] `ReleaseAssetDownloader`実装
- [ ] `DMGMounter`実装（`Process`+`hdiutil attach -nobrowse -plist`）
- [ ] `ZipExtractor`実装（ZIPFoundation）
- [ ] `ApplicationsInstaller`実装（`/Applications`へのコピー、既存同名`.app`の上書き確認）
- [ ] `AppInstaller`実装（ダウンロード〜展開〜コピーの一連の流れを束ねるFacade）
- [ ] `InstallError`定義（`downloadFailed`/`mountFailed`/`extractionFailed`/`appBundleNotFound`/`permissionDenied`/`alreadyInstalledNewerVersion`/`cancelled`。各分岐でユーザーに次アクション（リトライ/権限設定案内）を提示）
- [ ] `InstallationViewModel`/`InstallProgressView`実装

**技術的制約**: 他アプリを`/Applications`に書き込みインストールする処理と、`hdiutil`を`Process`経由で呼び出す処理は、どちらもApp Sandbox環境では実現不可能。これがPhase0で「App Sandbox capabilityを付与しない」と決めた直接の理由であり、Mac App Store配布を選択肢から外している根拠でもある。

**要確認事項（ユーザーへの再確認が必要）**: ノイズ除去条件を検討していた壁打ち時点では、ユーザーは`.app`/`.dmg`/`.pkg`の3形式を許容する案を支持していた。しかし実装計画のインストーラー設計では、`.pkg`インストーラーは`Process`経由の実行が権限まわりで複雑になることを理由に、対象外（`validAssetExtensions`は`.dmg`/`.zip`のみ）とされている。これはユーザーの初期選好からの逸脱であり、**Phase7着手時に`.pkg`対応を本当に見送るか改めて確認する**（CLAUDE.mdの「制約を内部で判断して黙って別の方法を採用しない」という方針に従う）。

**該当するデザインパターン**: Factory（`InstallService`内で`.dmg`/`.zip`の種別からハンドラを生成する部分）、Facade（`AppInstaller`がダウンロード〜展開〜コピーの複雑な処理を単純なAPIにまとめる部分）

**テスト方針**:
- `ZipExtractorTests`: 正常展開、破損zipでのエラー発火
- `DMGMounterTests`: `hdiutil`のplist出力パース成功/失敗（`Process`実行部分とパース部分を分離してテストする）

## Phase 8: アンインストール機能 — 未着手

**フロー（AppCleaner風）**:
```
ResidualFileScanner.scan(bundleIdentifier) — 以下をdry-runで存在確認:
  ~/Library/Application Support/{bundleId or AppName}
  ~/Library/Preferences/{bundleId}.plist
  ~/Library/Caches/{bundleId}
  ~/Library/Saved Application State/{bundleId}.savedState
  ~/Library/Logs/{AppName}
→ 削除対象一覧をチェックボックス付き確認ダイアログで表示(個別に外せる)
→ ユーザー確認後、FileManager.trashItem(at:) でゴミ箱移動
   （即時完全削除ではなくゴミ箱移動。誤削除時に復元可能にする安全策）
→ InstalledAppレコード削除、結果サマリ表示
```

- [ ] `ResidualFileScanner`実装（既知ディレクトリパターンのdry-runスキャン）
- [ ] `UninstallConfirmationInfo`実装（チェックボックス付き確認ダイアログ用のモデル）
- [ ] `AppUninstaller`実装（`FileManager.trashItem(at:)`によるゴミ箱移動）
- [ ] `LibraryView`実装（インストール済みアプリ一覧、アンインストール導線）

**判断背景（要注意）**: 壁打ち時のユーザー要件を言葉として捉えると「関連ファイルも含めて完全削除（AppCleaner風）」だったが、実際の削除方式について別途確認したところ、ユーザーは「ゴミ箱移動（誤削除時に復元可能な安全策）」を選んでいる。「完全削除」という語感と「ゴミ箱移動（即時削除ではない）」という実装内容にニュアンスのズレがあるため、**Phase8着手時にこの実装方針（即時完全削除ではなくTrash経由）で問題ないか改めて確認する**。

**技術的制約**: 他アプリの`~/Library/Application Support`, `Preferences`, `Caches`等、bundle identifierディレクトリを探索・削除する処理はApp Sandbox環境では実現不可能（Phase7と同様の制約）。

**テスト方針**:
- `ResidualFileScannerTests`: 既知ディレクトリパターンの正しいパス候補を一時ディレクトリでモックして検証

## Phase 9: Sparkle統合 — 未着手

**判断背景**: Sparkleは壁打ちの最初期（配布方式・SPM選定の段階）でユーザーが即座に「確実に欲しい」と確定させた唯一の必須ライブラリ。EdDSA署名（`generate_keys`/`sign_update`）を必須級で組み込むのは、実装計画側の判断——アプリ自体が完全無署名で配布される（Phase10参照）ため、Sparkleの署名検証機構こそが更新の真正性を保証する唯一の手段になる、という理由。OSレベルのコード署名の有無とは独立して機能し続けるため、無署名配布であってもEdDSA署名だけは省略できない。

appcast.xmlのホスティング先は壁打ち時点では未解決だったが、最終的に「GitHub Releasesのアセットとして配置する（追加インフラ不要でシンプル）」に確定している。

- [ ] `SPUStandardUpdaterController`組み込み
- [ ] EdDSA鍵生成（`generate_keys`）、リリース時の署名（`sign_update`）
- [ ] `appcast.xml`雛形作成（GitHub Releasesアセットとしてホスティング）

**テスト方針**: Sparkleフレームワーク自体は実装計画のテスト方針表に対象として明記されていない（外部フレームワークのためテスト対象外という前提と考えられる）。

## Phase 10: 配布パッケージング — 未着手

**判断背景**: 配布はDeveloper ID証明書を保有していないため完全無署名（`CODE_SIGN_IDENTITY=""`相当、Xcodeのデフォルト"Sign to Run Locally"のまま、あるいはPackage.swift運用なら署名ステップ自体を省略）で行う。既存の個人運用Homebrew tapリポジトリ（他の自作アプリ・CLIも既に管理している）に`cairn.rb`を追加する形を取るのは、新規tap作成ではなく既存運用に乗せたいというユーザーの要望による。

バージョン管理方式は`version.env`による単一チャンネル（`MARKETING_VERSION`/`BUILD_NUMBER`のみ）を採用済み（Phase0）。デュアルチャンネル方式（Stable/Beta）も検討したが、新規プロジェクトで最初からBeta配信を二重運用するのは過剰（YAGNI）と判断し不採用にした。将来Beta配信が必要になれば`version.env`にキーを追加するだけで移行できる設計にしてある。

依存関係の採用基準（Phase10で確立し、Phase6の`swift-markdown`検討など以降のフェーズにも適用する）: 「基本はApple標準APIで実装し、無駄な実装を避ける。ただし広く使われている定番SPMなら追加してよい」。

- [ ] `scripts/build-dmg.sh`実装（`create-dmg`利用、`brew install create-dmg`が前提。背景画像・アイコン配置・ドロップリンクを含むdmgを生成）
- [ ] `.app`バンドル組み立てスクリプト実装（`Info.plist`/`Cairn.entitlements`を`Resources/`からバンドルへコピー）
- [ ] `version.env`からのバージョン反映（dmgファイル名・GitHub Releaseタグ・Homebrew Caskの`version`・Sparkle appcast.xmlエントリを単一の真実源として生成）
- [ ] Homebrew Cask定義`cairn.rb`作成し、既存の個人運用tapリポジトリへ追加（`depends_on macos: ">= :tahoe"`, `zap trash:`で残留ファイル定義）
- [ ] Gatekeeper案内文言をREADME/初回起動画面に必須級で明記（`xattr -d com.apple.quarantine`、またはシステム設定からの許可手順。完全無署名のため通常のDeveloper ID署名版より警告が強く出る）
- [ ] `release.yml`の肉付け（Phase0.5で作成した雛形は、`scripts/build-dmg.sh`と`.app`バンドル組み立てスクリプトが揃うこのフェーズで初めて最後まで動くようになる）

**検証方法**: `brew audit --cask cairn` / `brew style`でCask定義を確認。Gatekeeper警告が実際に出ること、案内文言通りの回避手順で起動できることを実機で確認。

## Phase 10.5: オンボーディング — 未着手

**判断背景（このフェーズが生まれた経緯）**: 当初の計画にはオンボーディング専用フェーズは存在しなかった。Plan承認後の追加調査で、個人の参考実装にあったオンボーディングUIパターン（権限行の状態管理: `.granted`/`.needsAction`/`.blocked`、ステップ形式ラッパー）を調べる過程で「Permiso」ライブラリ（`NSWorkspace`ベースでシステム設定アプリの該当項目へオーバーレイ誘導するUXライブラリ）を発見したことがきっかけで、独立フェーズとして追加された。Permisoの`.appManagement`パネル（`Privacy_AppBundles`）が「他アプリのインストール・削除」というCairnの中核機能に直結する権限だったため、採用が決まった。

**重要な波及効果（最低対応OSがmacOS 15→26へ変わった経緯）**: Permisoの`Package.swift`が`platforms: [.macOS(.v26)]`を要求しており、当時確定していた最低対応OS（macOS 15 Sequoia以降）と衝突した。解決策として3択（Permisoをフォークして`Package.swift`の制約だけ緩和する／考え方だけ参考にして自前実装する／最低対応OSをmacOS 26 Tahoeに引き上げてそのまま使う）を検討し、**最低対応OSの引き上げを選択した**。これが現在の最低対応OS=macOS 26の直接の理由であり、実装計画ファイル単体を読むだけでは分からない経緯。

- [ ] `OnboardingPermissionRow`相当のUI実装（`PermissionRowStatus`による状態管理、Required/Optionalバッジ）
- [ ] ステップ形式オンボーディングのコンテナ・デザインシステム実装
- [ ] Welcome → GitHub OAuth認証(Device Flow) → App管理権限確認(Permiso `.appManagement`経由) → 完了、のフロー実装

**未解決事項**: Permisoのライセンス確認（GitHub上にLICENSEファイルが見当たらず、GitHub APIの`licenseInfo`もnull）。実装着手前に作者(zats)へ確認するか、配布不可と判断すれば独自実装に切り替える（既存の「既知の未解決事項」セクション参照。Phase10.5で実際に解決すべき項目として改めて紐づける）。

## Phase 11: 仕上げ — 未着手

**判断背景**: 特別な壁打ちはなく、当初から「全体テスト・空状態デザイン・設定画面の受け皿」として一貫して計画されていたフェーズ。

- [ ] `SettingsView`実装（アカウント状態・ログアウト、キャッシュクリア、Sparkle設定）
- [ ] 空状態（検索結果0件、ライブラリ空等）のデザイン実装
- [ ] 実リポジトリでのE2E手動確認一式（下記）

**判断背景（ログアウト時のキャッシュ）**: ログアウトしてもキャッシュ（`CachedRepository`/`CachedRelease`）はクリアしない。これらはユーザー非依存の公開情報のため、再ログイン時に再取得するコストを避ける。

**E2E手動確認項目**:
1. `swift build`/`swift test`でビルド・全ユニットテストを確認
2. 実機でDevice Flow認証フローを通しで確認（Phase1で実施済み）
3. 実在するSwift/Objective-C製macOSアプリのリポジトリ（Releasesに`.dmg`/`.zip`があるもの）で、検索→詳細表示→インストール→`/Applications`で起動確認→アンインストール→ゴミ箱に移動されていることを確認
4. `brew install --cask cairn`のローカル実行確認
5. Gatekeeper警告が実際に出ること、案内文言通りの回避手順で起動できることを確認

## テスト方針についての横断的な注記

実装計画のテスト方針表には、Phase4（`SearchViewModel`）、Phase5・6（UI層）、Phase9（Sparkle）、Phase10（配布パッケージング）、Phase10.5（オンボーディング）、Phase11（仕上げ）に対応する直接のテスト項目が明記されていない。明記されているのはPhase1（`GitHubRateLimiter`, `DeviceFlowAuthenticator`, `KeychainTokenStore`, `AuthenticationState`）、Phase3（`NoiseFilter`, `CategoryClassifier`）、Phase7（`ZipExtractor`, `DMGMounter`）、Phase8（`ResidualFileScanner`）のみ。CLAUDE.mdの「テストコードを必ず毎回の作業・タスクごとに適したものを追加すること」という方針に従い、テスト項目が明記されていないフェーズは着手時に自前でテスト戦略を設計すること。

## 既知の未解決事項

- **Permisoのライセンス確認**: GitHub上にLICENSEファイルが見当たらない。実装が進む前に作者へ確認が必要
- **`Package.swift`のみ運用でのXcode実用性**: SwiftUIプレビュー・デバッグ実行が問題なく動くか、実地確認がまだ済んでいない
