import Foundation
import Testing

@testable import Cairn

/// `waitIfNeeded`に注入したsleepクロージャが呼ばれた際の待機時間を記録するテスト用ヘルパー。
private actor SleepRecorder {
    private(set) var lastDuration: Duration?

    func record(_ duration: Duration) {
        lastDuration = duration
    }
}

@Suite("GitHubRateLimiterのレート制限追跡")
struct GitHubRateLimiterTests {
    private static let url = URL(string: "https://api.github.com/search/repositories")!

    private static func response(statusCode: Int = 200, headers: [String: String]) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: headers)!
    }

    @Test("レスポンスヘッダの値でremaining/limit/resetAtを補正する")
    func updatesFromResponseHeaders() async {
        let limiter = GitHubRateLimiter()
        let response = Self.response(headers: [
            "X-RateLimit-Remaining": "29",
            "X-RateLimit-Limit": "30",
            "X-RateLimit-Reset": "1700000000",
        ])

        await limiter.update(from: response)

        #expect(await limiter.remaining == 29)
        #expect(await limiter.limit == 30)
        #expect(await limiter.resetAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("後続レスポンスでremainingが上書きされる（自前カウントせずヘッダ実測値に追従）")
    func remainingFollowsLatestHeader() async {
        let limiter = GitHubRateLimiter()
        await limiter.update(from: Self.response(headers: ["X-RateLimit-Remaining": "10"]))
        await limiter.update(from: Self.response(headers: ["X-RateLimit-Remaining": "9"]))

        #expect(await limiter.remaining == 9)
    }

    @Test("429時にRetry-Afterヘッダから待機時間を算出し、経過後は待機不要になる")
    func recordsRetryAfterBackoff() async throws {
        let limiter = GitHubRateLimiter()
        let now = Date(timeIntervalSince1970: 1_000)
        let response = Self.response(statusCode: 429, headers: ["Retry-After": "5"])

        await limiter.recordRateLimited(response: response, now: now)

        let recorder = SleepRecorder()
        try await limiter.waitIfNeeded(
            now: now.addingTimeInterval(1),
            sleep: { duration in await recorder.record(duration) }
        )
        #expect(await recorder.lastDuration == .seconds(4))

        // 待機終了時刻を過ぎていればsleepを呼ばない。
        let secondRecorder = SleepRecorder()
        try await limiter.waitIfNeeded(
            now: now.addingTimeInterval(10),
            sleep: { duration in await secondRecorder.record(duration) }
        )
        #expect(await secondRecorder.lastDuration == nil)
    }

    @Test("Retry-Afterが無い429はX-RateLimit-Resetにフォールバックする")
    func fallsBackToRateLimitResetWhenRetryAfterMissing() async throws {
        let limiter = GitHubRateLimiter()
        let now = Date(timeIntervalSince1970: 1_000)
        let resetEpoch = now.addingTimeInterval(20).timeIntervalSince1970
        let response = Self.response(
            statusCode: 429,
            headers: ["X-RateLimit-Reset": String(Int(resetEpoch))]
        )

        await limiter.recordRateLimited(response: response, now: now)

        let recorder = SleepRecorder()
        try await limiter.waitIfNeeded(now: now, sleep: { duration in await recorder.record(duration) })
        #expect(await recorder.lastDuration == .seconds(20))
    }
}
