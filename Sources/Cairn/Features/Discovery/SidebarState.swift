import Defaults
import Observation

/// サイドバーのpinned/unpinned状態と、unpinned時のホバーによる一時オーバーレイ表示を管理する。
///
/// `docs/design/sidebar-interaction.md`のXcodeナビゲータ同様の挙動をSwiftUIで再現する。
/// トリガー領域とサイドバー本体の両方の`onHover`から`hoverEntered()`/`hoverExited()`を呼ぶ想定だが、
/// SwiftUIの`onHover`はビュー境界をまたぐ瞬間に両方falseになる隙間が生じ得るため、
/// 退場側に短いデバウンスを設けてフリッカーを防ぐ。
@Observable
@MainActor
final class SidebarState {
    /// 常時表示するか。次回起動時も保持するため`Defaults`と同期する。
    var isPinned: Bool {
        didSet {
            guard isPinned != oldValue else { return }
            Defaults[.isSidebarPinned] = isPinned
        }
    }

    /// unpinned時、ホバーによって一時的にオーバーレイ表示中かどうか。
    private(set) var isRevealed = false

    private let sleep: @Sendable (Duration) async throws -> Void
    private var hideTask: Task<Void, Never>?

    /// デバウンス退場までの待機時間。
    static let hideDelay: Duration = .milliseconds(80)

    /// - Parameters:
    ///   - isPinned: 初期状態。デフォルトは`Defaults[.isSidebarPinned]`。
    ///   - sleep: `hoverExited()`のデバウンス待機を差し替えるためのテスト用注入ポイント。
    init(
        isPinned: Bool = Defaults[.isSidebarPinned],
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.isPinned = isPinned
        self.sleep = sleep
    }

    func togglePinned() {
        isPinned.toggle()
    }

    /// 左端トリガー領域 or サイドバー本体のいずれかにカーソルが入った時に呼ぶ。
    func hoverEntered() {
        hideTask?.cancel()
        hideTask = nil
        isRevealed = true
    }

    /// 両方の領域からカーソルが外れた時に呼ぶ。即座には隠さず、`hideDelay`後に隠す
    /// （その間に`hoverEntered()`が呼ばれればキャンセルされ、隠れない）。
    func hoverExited() {
        hideTask?.cancel()
        hideTask = Task { [sleep] in
            do {
                try await sleep(Self.hideDelay)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            isRevealed = false
        }
    }
}
