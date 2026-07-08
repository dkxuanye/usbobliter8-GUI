import XCTest
@testable import EraseA12

/// Mock URLProtocol：拦截所有 URLSession 请求
final class MockURLProtocol: URLProtocol {

    typealias Handler = (URLRequest) -> (HTTPURLResponse, Data?, Error?)
    static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data, error) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else if let data = data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// 单例 mock URLSession 工厂：把 URLSession 的 protocolClasses 替换成 [MockURLProtocol.self]
private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

final class UpdateCheckerTests: XCTestCase {

    var checker: UpdateChecker!
    var mockSession: URLSession!

    override func setUp() {
        super.setUp()
        mockSession = makeMockSession()
        checker = UpdateChecker(session: mockSession)
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        checker = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func respondJSON(_ json: String, statusCode: Int = 200) {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/update.json")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        let data = json.data(using: .utf8)
        MockURLProtocol.handler = { _ in (response, data, nil) }
    }

    private func respondNetworkError(_ error: Error = URLError(.timedOut)) {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/update.json")!,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        MockURLProtocol.handler = { _ in (response, nil, error) }
    }

    private func waitForCompletion(
        _ checker: UpdateChecker,
        endpoint: URL = URL(string: "https://example.com/update.json")!,
        currentVersion: String = "1.0.0"
    ) -> UpdateChecker.UpdateResult? {
        let exp = expectation(description: "completion")
        var captured: UpdateChecker.UpdateResult?
        checker.checkForUpdate(endpoint: endpoint, currentVersion: currentVersion) { result in
            captured = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
        return captured
    }

    // MARK: - 版本一致 → .current

    func test_currentVersion_whenRemoteMatches_callsCurrent() {
        respondJSON(#"{"version":"1.0.0"}"#)

        let result = waitForCompletion(checker, currentVersion: "1.0.0")

        XCTAssertEqual(result, .current)
    }

    // MARK: - 版本不一致 → .outdated

    func test_currentVersion_whenRemoteDiffers_callsOutdated() {
        respondJSON(#"{"version":"1.0.1"}"#)

        let result = waitForCompletion(checker, currentVersion: "1.0.0")

        XCTAssertEqual(result, .outdated(remote: "1.0.1"))
    }

    // MARK: - 网络失败 → .networkError

    func test_currentVersion_whenNetworkFails_callsNetworkError() {
        respondNetworkError(URLError(.timedOut))

        let result = waitForCompletion(checker, currentVersion: "1.0.0")

        guard case .networkError = result else {
            XCTFail("Expected .networkError, got \(String(describing: result))")
            return
        }
    }

    // MARK: - JSON 缺 version 字段 → .outdated

    func test_currentVersion_whenJSONMissingVersion_callsOutdated() {
        respondJSON(#"{}"#)

        let result = waitForCompletion(checker, currentVersion: "1.0.0")

        XCTAssertEqual(result, .outdated(remote: ""))
    }

    // MARK: - version 字段为空 → .outdated

    func test_currentVersion_whenVersionFieldEmpty_callsOutdated() {
        respondJSON(#"{"version":""}"#)

        let result = waitForCompletion(checker, currentVersion: "1.0.0")

        XCTAssertEqual(result, .outdated(remote: ""))
    }

    // MARK: - 默认从 bundle 读 CFBundleShortVersionString

    func test_currentVersion_usesCFBundleShortVersionString_byDefault() {
        respondJSON(#"{"version":"1.0.0"}"#)

        // 不传 currentVersion，应从 bundle infoDictionary 读
        // 测试 bundle 的 CFBundleShortVersionString 是 "1.0.0"（见 project.yml / Info.plist）
        let exp = expectation(description: "completion")
        var captured: UpdateChecker.UpdateResult?
        checker.checkForUpdate(
            endpoint: URL(string: "https://example.com/update.json")!
        ) { result in
            captured = result
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)

        XCTAssertEqual(captured, .current, "Should use bundle's CFBundleShortVersionString and match remote")
    }
}