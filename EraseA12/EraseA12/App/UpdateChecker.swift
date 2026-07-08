import Foundation

/// 联网版本验证器
///
/// 启动时调用 `checkForUpdate`，从远端 `update.json` 读取版本号，
/// 与本地 `CFBundleShortVersionString` 比较，结果通过回调返回。
/// 失败保守策略：JSON 解析失败或字段缺失视为过期，宁可多弹一次也别漏掉更新。
final class UpdateChecker {

    /// 默认远端端点
    static let defaultEndpoint = URL(string: "https://www.dkxuanye.fit/EraseA12/update.json")!

    /// 网络请求超时（秒）
    static let requestTimeout: TimeInterval = 15

    /// 单例（生产代码使用）
    static let shared = UpdateChecker()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Result

    enum UpdateResult: Equatable {
        /// 版本一致，静默放行
        case current
        /// 版本不一致，弹升级窗
        case outdated(remote: String)
        /// 网络失败，弹重试/退出/继续使用窗
        case networkError(reason: String)
    }

    // MARK: - Public API

    /// 检查远端版本号
    /// - Parameters:
    ///   - endpoint: 默认 `https://www.dkxuanye.fit/EraseA12/update.json`
    ///   - currentVersion: 默认从 bundle 读 `CFBundleShortVersionString`
    ///   - completion: 回调在**主线程**执行
    func checkForUpdate(
        endpoint: URL? = nil,
        currentVersion: String? = nil,
        completion: @escaping (UpdateResult) -> Void
    ) {
        let url = endpoint ?? Self.defaultEndpoint
        let localVersion = currentVersion ?? Self.currentBundleVersion()

        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.httpMethod = "GET"

        let task = session.dataTask(with: request) { data, response, error in
            let result = Self.classify(data: data, response: response, error: error, localVersion: localVersion)
            DispatchQueue.main.async {
                completion(result)
            }
        }
        task.resume()
    }

    // MARK: - Internal

    /// 从 main bundle 读 CFBundleShortVersionString，失败回落到 "1.0.0"
    static func currentBundleVersion() -> String {
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !v.isEmpty {
            return v
        }
        return "1.0.0"
    }

    /// 把网络响应归类为 UpdateResult
    static func classify(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        localVersion: String
    ) -> UpdateResult {
        // 1. 网络层错误优先
        if let error = error {
            return .networkError(reason: error.localizedDescription)
        }

        // 2. 检查 HTTP 状态码（仅 200 OK 算成功）
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return .networkError(reason: "HTTP \(http.statusCode)")
        }

        // 3. 必须有数据
        guard let data = data, !data.isEmpty else {
            return .networkError(reason: "no data")
        }

        // 4. 解析 JSON
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // 解析失败 → 保守视为过期
            return .outdated(remote: "")
        }

        // 5. 读 version 字段，空字符串也视为过期
        let remote = (json["version"] as? String) ?? ""
        if remote.isEmpty {
            return .outdated(remote: "")
        }

        // 6. 字符串等值比较
        if remote == localVersion {
            return .current
        }
        return .outdated(remote: remote)
    }
}