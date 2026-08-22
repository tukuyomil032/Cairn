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

## Phase 3〜11 — 未着手

ノイズ除去・分類ロジック / 検索アーキテクチャ / Discovery UI / AppDetail UI / インストール機能 / アンインストール機能 / Sparkle統合 / 配布パッケージング / オンボーディング / 仕上げ。詳細は実装計画ファイル参照。

## 既知の未解決事項

- **Permisoのライセンス確認**: GitHub上にLICENSEファイルが見当たらない。実装が進む前に作者へ確認が必要
- **`Package.swift`のみ運用でのXcode実用性**: SwiftUIプレビュー・デバッグ実行が問題なく動くか、実地確認がまだ済んでいない
