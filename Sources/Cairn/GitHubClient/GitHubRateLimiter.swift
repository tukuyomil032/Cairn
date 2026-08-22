import Foundation

/// GitHub REST APIのレート制限状態を追跡するアクター。
///
/// GitHubはリクエスト毎に`X-RateLimit-*`ヘッダで最新の残量を返してくるため、
/// 自前でカウントするのではなくレスポンスヘッダの値で都度補正する方式を取る。
/// 429（もしくは403のレート制限超過）を受けた場合は`Retry-After`（無ければ
/// `X-RateLimit-Reset`）から算出した待機時間を保持し、呼び出し側はリクエスト
/// 前に`waitIfNeeded()`でその待機を消化する。
actor GitHubRateLimiter {
    private(set) var remaining: Int?
    private(set) var limit: Int?
    private(set) var resetAt: Date?
    private var retryAfterUntil: Date?

    /// レスポンスヘッダから残量・上限・リセット時刻を読み取り状態を更新する。
    func update(from response: HTTPURLResponse) {
        if let remaining = response.intHeaderValue(for: "X-RateLimit-Remaining") {
            self.remaining = remaining
        }
        if let limit = response.intHeaderValue(for: "X-RateLimit-Limit") {
            self.limit = limit
        }
        if let resetEpochSeconds = response.intHeaderValue(for: "X-RateLimit-Reset") {
            self.resetAt = Date(timeIntervalSince1970: TimeInterval(resetEpochSeconds))
        }
    }

    /// 429を受けた際に、次のリクエストまでの待機終了時刻を記録する。
    /// `Retry-After`ヘッダがあれば優先し、無ければ`X-RateLimit-Reset`にフォールバックする。
    func recordRateLimited(response: HTTPURLResponse, now: Date = Date()) {
        if let retryAfterSeconds = response.intHeaderValue(for: "Retry-After") {
            retryAfterUntil = now.addingTimeInterval(TimeInterval(retryAfterSeconds))
        } else if let resetEpochSeconds = response.intHeaderValue(for: "X-RateLimit-Reset") {
            retryAfterUntil = Date(timeIntervalSince1970: TimeInterval(resetEpochSeconds))
        }
        update(from: response)
    }

    /// 記録済みの待機終了時刻を過ぎるまで呼び出し元をサスペンドする。待機が不要なら即座に返る。
    func waitIfNeeded(
        now: Date = Date(), sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) async throws {
        guard let until = retryAfterUntil, until > now else { return }
        let seconds = until.timeIntervalSince(now)
        try await sleep(.seconds(seconds))
        retryAfterUntil = nil
    }
}

extension HTTPURLResponse {
    fileprivate func intHeaderValue(for field: String) -> Int? {
        guard let value = value(forHTTPHeaderField: field) else { return nil }
        return Int(value)
    }
}
