import Foundation

/// `AuthenticationStateTests`専用の`URLProtocol`スタブ。
///
/// `DeviceFlowAuthenticatorTests`の`DeviceFlowStubURLProtocol`と実装は同じだが、
/// 静的なスタブ格納領域をクラスごとに分離するために別クラスとして用意している。
/// 複数スイートが`swift test`で並列実行されるため、単一クラスを共有すると
/// 片方の`reset()`がもう片方の登録済みスタブを消してしまうレースコンディションが発生する。
final class AuthenticationStateStubURLProtocol: URLProtocol {
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

    private static func nextStub(forPath path: String) -> Stub? {
        guard var queue = stubQueues[path], let first = queue.first else { return nil }
        if queue.count > 1 {
            queue.removeFirst()
            stubQueues[path] = queue
        }
        return first
    }
}
