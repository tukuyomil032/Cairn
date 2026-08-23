import Defaults
import Testing

@testable import Cairn

/// テストから明示的に解放するまで`sleep`を保留させるゲート。
/// `SidebarState.hoverExited()`のデバウンス待機を制御するために使う。
private actor SleepGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
@Suite("サイドバーのpinned/unpinned + ホバー状態")
struct SidebarStateTests {
    @Test("Defaultsの初期値をisPinnedへ反映する")
    func initialValueReflectsDefaults() {
        let original = Defaults[.isSidebarPinned]
        defer { Defaults[.isSidebarPinned] = original }
        Defaults[.isSidebarPinned] = false

        let state = SidebarState()
        #expect(state.isPinned == false)
    }

    @Test("togglePinnedでDefaultsへ書き込まれる")
    func togglePinnedWritesToDefaults() {
        let original = Defaults[.isSidebarPinned]
        defer { Defaults[.isSidebarPinned] = original }

        let state = SidebarState(isPinned: true)
        state.togglePinned()

        #expect(state.isPinned == false)
        #expect(Defaults[.isSidebarPinned] == false)
    }

    @Test("hoverEnteredで即座にisRevealedがtrueになる")
    func hoverEnteredRevealsImmediately() {
        let state = SidebarState(isPinned: false, sleep: { _ in })

        #expect(state.isRevealed == false)
        state.hoverEntered()
        #expect(state.isRevealed == true)
    }

    @Test("hoverExited後はsleep完了までisRevealedがtrueのまま維持される")
    func hoverExitedKeepsRevealedUntilSleepCompletes() async {
        let gate = SleepGate()
        let state = SidebarState(isPinned: false, sleep: { _ in await gate.wait() })

        state.hoverEntered()
        state.hoverExited()
        await Task.yield()
        #expect(state.isRevealed == true)

        await gate.open()
        await pollUntil { state.isRevealed == false }
        #expect(state.isRevealed == false)
    }

    @Test("hoverExited直後のhoverEnteredでデバウンスがキャンセルされisRevealedが維持される")
    func hoverEnteredCancelsPendingHide() async {
        let gate = SleepGate()
        let state = SidebarState(isPinned: false, sleep: { _ in await gate.wait() })

        state.hoverEntered()
        state.hoverExited()
        await Task.yield()
        state.hoverEntered()

        await gate.open()
        await Task.yield()
        await Task.yield()
        #expect(state.isRevealed == true)
    }

    private func pollUntil(
        attempts: Int = 200,
        _ condition: @MainActor () -> Bool
    ) async {
        for _ in 0..<attempts {
            if condition() { return }
            await Task.yield()
        }
    }
}
