# 依存関係・参考プロジェクトの調査メモ

実装着手前（Phase 0）に調査した、依存パッケージと参考プロジェクトの採否判断の記録。判断の背景を残すことで、後から「なぜこれを使った/使わなかったか」を追跡できるようにする。

## 採用した依存パッケージ（`Package.swift`）

| パッケージ | 用途 | 採用理由 |
|---|---|---|
| [sparkle-project/Sparkle](https://github.com/sparkle-project/Sparkle) | 自動アップデート | Cairnは完全無署名配布（Developer ID証明書を保有していないため）。OSのコード署名検証が使えない分、Sparkle独自のEdDSA署名(`generate_keys`/`sign_update`)が更新の真正性を保証する唯一の手段になる。確定・必須 |
| [weichsel/ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | GitHub Releasesの`.zip`資産展開 | Foundation単体には実用的なzip展開APIが無い。`.dmg`は`hdiutil`（標準コマンド）で足りるため、圧縮形式のうち`.zip`だけをこれで補う |
| [sindresorhus/Defaults](https://github.com/sindresorhus/Defaults) | UserDefaultsの型安全ラッパー | キャッシュTTL・自動更新ON/OFFなど設定項目の型安全な読み書き。多くのSwiftプロジェクトで広く使われている定番のため採用 |
| [zats/permiso](https://github.com/zats/permiso) | システム設定アプリの権限項目へのオーバーレイ誘導 | 詳細は下記「Permiso」節 |

### 不採用にしたもの

| パッケージ | 検討理由 | 不採用の理由 |
|---|---|---|
| [SwiftyJSON/SwiftyJSON](https://github.com/SwiftyJSON/SwiftyJSON) | ユーザー提示 | 動的スキーマの緩いJSON処理に強みがあるが、CairnはGitHub APIの構造化レスポンスを`Codable`で型安全に扱う設計方針。緩い操作の利点を活かす場面がなく、Apple公式API優先の方針にも合わない |
| [SwifterSwift/SwifterSwift](https://github.com/SwifterSwift/SwifterSwift) | ユーザー提示 | 500以上の汎用Swift/Foundation拡張。全部をまとめて依存に加えるのは「極力Apple公式・最小依存」の方針に反する。必要な拡張（相対時間表示、文字列トリム等）はその都度自前実装する方針 |
| [SFSafeSymbols](https://github.com/SFSafeSymbols/SFSafeSymbols) | 実装計画の初期検討時に候補として挙がった | 最終的にユーザーが不採用を確定。`Image(systemName:)`の直書きで対応する |

### 参考資料として活用（依存には追加しない）

| リポジトリ | 用途 |
|---|---|
| [ochococo/Design-Patterns-In-Swift](https://github.com/ochococo/Design-Patterns-In-Swift) | 学習用リポジトリ（ライブラリではない、2024年更新止まり）。Cairnのアーキテクチャで実際に対応するパターン一覧は下記参照 |
| [amosgyamfi/open-swiftui-animations](https://github.com/amosgyamfi/open-swiftui-animations) | ライブラリではなく実装例集（コピペ用スニペット）。インストール進捗表示のアニメーション、カード表示のトランジション等、UIポリッシュフェーズで個別に参照する |

#### Design-Patterns-In-Swiftからの対応表

| パターン | Cairn内での適用箇所 |
|---|---|
| Protocol | `GitHubClientProtocol`（テスト時のモック差し替え） |
| Strategy | `NoiseFilter` / `Classifier`（判定ロジックの差し替え可能性） |
| Observer | Observation framework自体がこのパターンの実装 |
| Factory | `InstallService`内で`.dmg`/`.zip`の種別からハンドラを生成する部分 |
| Facade | `AppInstaller`がダウンロード〜展開〜コピーの複雑な処理を単純なAPIにまとめる部分 |

---

## Permiso (zats/permiso) — 詳細

### 何をするライブラリか

システム設定アプリの特定のプライバシー設定項目を`NSWorkspace`で開き、その項目の上にオーバーレイウィンドウを重ねて視覚的にスポットライトを当てるUXライブラリ。使い方は非常にシンプル:

```swift
import Permiso

@MainActor
func showAppManagementHelper() {
    PermisoAssistant.shared.present(panel: .appManagement)
}
```

対応パネル（`PermisoPanel` enum）:
- `.accessibility` (`Privacy_Accessibility`)
- `.screenRecording` (`Privacy_ScreenCapture`)
- **`.appManagement` (`Privacy_AppBundles`)** ← Cairnが使うのはこれ

### 採用理由

`.appManagement`パネルは「他アプリのインストール・変更・削除」を許可するmacOSの権限設定そのものであり、**Cairnの中核機能（GitHub Releasesから取得したアプリを`/Applications`にインストールし、不要になったら関連ファイルごとアンインストールする）に直結する**。この権限が未許可の状態でインストール/アンインストールを試みると失敗するため、Permisoでシステム設定へスムーズに誘導できることは大きな価値がある。

中身の実装はAppKit標準API（`NSWorkspace`, `Timer`, `NSObjectProtocol`）のみで、サードパーティ依存も無い軽量な構成。

### 注意点・未解決事項

1. **`Package.swift`が`platforms: [.macOS(.v26)]`を必須にしている。** これに合わせてCairnの最低対応OSも当初予定の macOS 15 Sequoia から **macOS 26 Tahoe** に引き上げた（実装計画セクション11参照）。中身自体はmacOS 15でも動きそうな実装だが、SwiftPM上はこのplatforms指定より低いバージョンのプロジェクトから直接依存できない。
2. **ライセンスファイルが見当たらない。** GitHub上にLICENSEファイルが存在せず、GitHub APIの`licenseInfo`も空(`null`)。実装着手前に作者(zats)へライセンスを確認するか、リポジトリ内に追記がないか再確認する必要がある。**この確認が完了するまで、配布ビルドには含めない判断もあり得る。**

---

## バージョン管理・ビルド運用（steipete/CodexBar, tukuyomil032/Perch）

Cairnと同じくSwift製macOSアプリを個人開発しているユーザーの2プロジェクトを調査し、以下を踏襲する。

### `Package.swift`のみでの運用（CodexBar方式）

[steipete/CodexBar](https://github.com/steipete/CodexBar)は`.xcodeproj`を持たず、`Package.swift`の`executableTarget`でGUIアプリ本体を直接定義している。Cairnもこれに倣い`Cairn.xcodeproj`を作らず、`Package.swift`一本で依存関係とターゲットを管理する（実装計画セクション10.7）。

- **メリット**: Xcodeプロジェクトファイルの差分がGitの競合を起こしにくい、CLIビルドがシンプル、依存関係が`Package.swift`一箇所に集約される
- **デメリット**: Xcode上でのSwiftUIプレビューの体験がXcodeプロジェクトほど滑らかではない場合がある。Xcode 15以降は`Package.swift`を直接開いて実行・プレビュー可能なため、実用上の支障は小さいと考えられるが、Phase 0で実地確認する
- SwiftPMは`Info.plist`をリソースバンドルのトップレベルに含めることを禁止しているため、`Sources/Cairn/Resources/Info.plist`は`Package.swift`の`exclude`でリソース処理から除外し、リリース時のビルドスクリプトが`.app`バンドルへ手動コピーする運用にした

### `version.env`によるバージョン管理

CodexBarとPerch([tukuyomil032/Perch](https://github.com/tukuyomil032/Perch))はどちらもリポジトリ直下に`version.env`という単純なキーバリューファイルを置き、ビルドスクリプト・CIがそこからバージョン番号を読み取っている。

- **CodexBar方式**（単一チャンネル）: `MARKETING_VERSION` / `BUILD_NUMBER`
- **Perch方式**（Stable/Beta 2チャンネル）: `STABLE_MARKETING_VERSION` / `STABLE_BUILD_NUMBER` / `BETA_MARKETING_VERSION` / `BETA_PRERELEASE_NUMBER` / `BETA_BUILD_NUMBER`

Cairnは初期段階では**CodexBar方式（単一チャンネル）**を採用する（`version.env`参照）。理由: 新規プロジェクトでBeta配信チャンネルを最初から二重運用するのはYAGNIに反する。将来Beta配信が必要になれば、`version.env`にキーを追加するだけでPerch方式に移行できる。

### dmgパッケージング

Perchの`scripts/build-dmg.sh`（`create-dmg`ツールを利用、`brew install create-dmg`が前提）を参考に、Cairnでも同様のスクリプトを用意する（Phase 10で実装）。背景画像・アイコン配置・ドロップリンクを含むdmgを生成できる。

### 署名について（重要な差分）

CodexBarはDeveloper ID署名 + 公証を行っている（`.mac-release.env`に`MAC_RELEASE_CODESIGN_IDENTITY`等の設定がある）。**Cairnはこの部分を踏襲しない。** ユーザーはApple Developer Programに加入しておらずDeveloper ID証明書を持っていないため、Cairnは**完全無署名配布**とする（実装計画セクション10.5）。CodexBar・Perchのビルドスクリプトからは、バージョン管理・dmg生成・appcast更新の仕組みだけを流用し、コード署名・公証のステップは含めない。

---

## Snapzy(ローカル既存プロジェクト) Onboarding — オンボーディングUIの参考

`Features/Onboarding/`配下の構成を参考にする:

- `OnboardingPermissionRow.swift`: `PermissionRowStatus`(`.granted` / `.needsAction` / `.blocked`)という3状態のenumで権限行の見た目を切り替えるパターン。Required/Optionalバッジ、`.blocked`時のコーナーバッジ（テキストピルではなく警告アイコン+ツールチップ）というデザイン上の工夫がある
- `OnboardingStepContainer.swift` / `OnboardingSurfaceBackground.swift` / `OnboardingVSDesignSystem.swift`: ステップ形式オンボーディングの共通ラッパーとデザインシステムの分離
- 複数ステップ構成（Welcome → 権限 → ショートカット → 完了、等）の設計パターン

**Cairn独自のオンボーディングフロー案**（Phase 10.5で実装）:

```
Welcome → GitHub OAuth認証(Device Flow) → App管理権限確認(Permiso .appManagement経由) → 完了
```

Snapzyの`PermissionRowStatus`パターンをそのままCairnの権限行UI（App管理権限の許可状態表示）に転用する。
