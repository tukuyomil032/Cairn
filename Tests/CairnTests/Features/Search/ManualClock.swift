import Foundation

@testable import Cairn

/// デバウンス・重複クエリ抑制のテスト用に、時刻を手動で進められる`Clock`実装。
/// 実際に300ms/5秒待つ実待機を避けるための注入ポイント。
final class ManualClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.offset < rhs.offset }
        static func == (lhs: Instant, rhs: Instant) -> Bool { lhs.offset == rhs.offset }

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }
    }

    private(set) var now = Instant(offset: .zero)
    let minimumResolution: Duration = .zero

    private var pendingWaiters: [(deadline: Instant, continuation: CheckedContinuation<Void, Never>)] = []

    func sleep(until deadline: Instant, tolerance: Duration? = nil) async throws {
        guard deadline > now else { return }
        await withCheckedContinuation { continuation in
            pendingWaiters.append((deadline, continuation))
        }
    }

    /// 時刻を進め、その時点で満了した待機者をすべて再開する。
    func advance(by duration: Duration) async {
        now = now.advanced(by: duration)
        let ready = pendingWaiters.filter { $0.deadline <= now }
        pendingWaiters.removeAll { $0.deadline <= now }
        for waiter in ready {
            waiter.continuation.resume()
        }
        // 再開されたTaskが次のawaitへ進む猶予を与える。
        await Task.yield()
    }

    /// テスト対象のTaskが`sleep(until:tolerance:)`を呼び出し、待機登録を終えるまで待つ。
    /// 並列テスト実行下ではスケジューリング遅延が生じうるため、固定回数のyieldではなく
    /// 実際に登録が完了したことをポーリングで確認してから`advance(by:)`を呼ぶ必要がある。
    func waitForPendingSleep(count: Int = 1, attempts: Int = 1000) async {
        for _ in 0..<attempts {
            if pendingWaiters.count >= count { return }
            await Task.yield()
        }
    }
}
