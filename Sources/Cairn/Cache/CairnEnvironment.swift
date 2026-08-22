import Foundation
import SwiftData

/// アプリ全体で共有する永続化コンテナを保持する軽量な環境容器。
///
/// Phase2時点ではModelContainerのみを保持する。GitHubClient/AuthenticationState等の
/// 実配線はUI機能フェーズで本容器を拡張して行う（その際はApp/への移動を検討する）。
@MainActor
final class CairnEnvironment {
    let modelContainer: ModelContainer

    /// - Parameter inMemory: `true`の場合、ディスクへ永続化しないインメモリコンテナを生成する（テスト用）。
    ///   本番の通常起動では`false`（デフォルト）を使う。
    init(inMemory: Bool = false) {
        let schema = Schema([
            CachedRepository.self,
            CachedRelease.self,
            InstalledApp.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainerの初期化に失敗しました: \(error)")
        }
    }
}
