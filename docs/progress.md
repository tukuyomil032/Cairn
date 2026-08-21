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

## Phase 1: GitHub APIクライアント層 + 認証 — 未着手

**事前準備（ユーザー作業、未実施）**: GitHub OAuth App作成（Device Flow有効化、Client ID取得）。

- [ ] `GitHubModels`定義
- [ ] `GitHubRateLimiter`実装
- [ ] `GitHubClient`基本実装（search/releases/readme/user）
- [ ] `DeviceFlowAuthenticator`実装
- [ ] `KeychainTokenStore`実装
- [ ] `AuthenticationState`実装
- [ ] refresh token自動更新ロジック
- [ ] `GitHubClient`への認証統合
- [ ] `DeviceFlowSignInView`実装

## Phase 2〜11 — 未着手

永続化層 / ノイズ除去・分類ロジック / 検索アーキテクチャ / Discovery UI / AppDetail UI / インストール機能 / アンインストール機能 / Sparkle統合 / 配布パッケージング / オンボーディング / 仕上げ。詳細は実装計画ファイル参照。

## 既知の未解決事項

- **Permisoのライセンス確認**: GitHub上にLICENSEファイルが見当たらない。実装が進む前に作者へ確認が必要
- **`Package.swift`のみ運用でのXcode実用性**: SwiftUIプレビュー・デバッグ実行が問題なく動くか、実地確認がまだ済んでいない
