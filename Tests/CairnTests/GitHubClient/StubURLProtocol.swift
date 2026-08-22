import Foundation

/// `URLSession`をネットワークに触れずスタブ化するための`URLProtocol`。
/// パスごとにレスポンスを登録し、実際に組み立てられたリクエストをそのまま検証できるようにする。
/// 同一パスに複数レスポンスを登録した場合は呼び出し順に消費し、最後の1件は使い切られても
/// 繰り返し返す（ポーリング処理のテストで「N回目に成功する」パターンを表現するため）。
final class StubURLProtocol: URLProtocol {
    struct Stub: Sendable {
        let statusCode: Int
        let headers: [String: String]
        let body: Data
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var stubQueues: [String: [Stub]] = [:]
    nonisolated(unsafe) private static var recordedRequests: [URLRequest] = []

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        stubQueues = [:]
        recordedRequests = []
    }

    static func stub(path: String, statusCode: Int = 200, headers: [String: String] = [:], body: Data) {
        stub(path: path, sequence: [Stub(statusCode: statusCode, headers: headers, body: body)])
    }

    static func stub(path: String, sequence: [Stub]) {
        lock.lock()
        defer { lock.unlock() }
        stubQueues[path] = sequence
    }

    static func recordedRequests(matching path: String) -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recordedRequests.filter { $0.url?.path == path }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        Self.lock.lock()
        Self.recordedRequests.append(request)
        let stub = Self.nextStub(forPath: path)
        Self.lock.unlock()

        guard let stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: stub.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// ロック取得済みの状態で呼ぶこと。キューが2件以上あれば先頭を消費し、最後の1件は残し続ける。
    private static func nextStub(forPath path: String) -> Stub? {
        guard var queue = stubQueues[path], let first = queue.first else { return nil }
        if queue.count > 1 {
            queue.removeFirst()
            stubQueues[path] = queue
        }
        return first
    }
}
