# EraseA12 联网更新检查 - 设计文档

**日期**：2026-07-08
**作者**：玄烨品果
**状态**：已批准，待实现

---

## 目标

为 EraseA12 增加启动时联网版本验证功能，避免应用退化成单机版。当远端版本号与本地不一致时，强制用户看到提示并前往更新页。

## 背景

EraseA12 当前没有任何更新检查机制。开发者每次发布新版本都依赖用户主动访问 dkxuanye.cn 看到新文章，使用上滞后且容易错过重要修复。需要在应用启动时联网比对版本号，发现不一致立即弹窗。

## 设计

### update.json 数据结构

极简档，只有一个 `version` 字段：

```json
{
  "version": "1.0.0"
}
```

- 部署在 `https://www.dkxuanye.fit/EraseA12/update.json`
- 与本地 `Info.plist` 的 `CFBundleShortVersionString` 字段进行字符串等值比较
- 解析失败、字段缺失、值为空都视为"过期"，按过期逻辑处理（保守策略）

### 架构

**新文件**：

| 文件 | 职责 |
|---|---|
| `EraseA12/EraseA12/App/UpdateChecker.swift` | 网络请求 + JSON 解析 + 版本对比 + 弹窗调用 |
| `EraseA12/EraseA12Tests/UpdateCheckerTests.swift` | 单元测试，mock URLProtocol |

**修改文件**：

| 文件 | 改动 |
|---|---|
| `EraseA12/EraseA12/App/AppDelegate.swift` | 在 `applicationDidFinishLaunching` 末尾调用 `UpdateChecker.shared.checkForUpdate()` |
| `EraseA12/EraseA12/Resources/zh-Hans.lproj/Localizable.strings` | 新增弹窗文案 key |
| `EraseA12/EraseA12/Resources/en.lproj/Localizable.strings` | 同步英文 key（仅数据完整性，不显示） |
| `EraseA12/project.yml` | 无需改动（xcodegen 自动包含新增 .swift 文件） |
| `docs/ARCHITECTURE.md` | 新增 UpdateChecker 模块说明 |
| `HANDOFF.md`、`DEV_LOG.md`、`TODO.md` | 同步进展 |

### UpdateChecker 接口

```swift
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// 检查远端版本号，结果通过回调传递
    /// - Parameters:
    ///   - endpoint: 默认 `https://www.dkxuanye.fit/EraseA12/update.json`
    ///   - currentVersion: 默认从 bundle 读 CFBundleShortVersionString
    ///   - completion: 主线程回调，收到 .current/.outdated/.networkError 任一
    func checkForUpdate(
        endpoint: URL = ...,
        currentVersion: String = ...,
        completion: @escaping (UpdateResult) -> Void
    )

    enum UpdateResult: Equatable {
        case current                    // 版本一致
        case outdated(remote: String)   // 版本不一致，弹升级窗
        case networkError(reason: String) // 网络失败，弹重试窗
    }
}
```

### 数据流

```
App 启动
  → AppDelegate.applicationDidFinishLaunching
    → 创建并显示主窗口
    → UpdateChecker.shared.checkForUpdate { result in
        switch result {
        case .current:
            // 静默，啥都不做
        case .outdated(let remote):
            let alert = NSAlert()
            alert.messageText = L10n.text("update.outdated_title", fallback: "发现新版本")
            alert.informativeText = "当前版本：\(current)\n最新版本：\(remote)\n\n\(L10n.text("update.outdated_body"))"
            alert.addButton(withTitle: "前往更新")
            alert.addButton(withTitle: "退出程序")
            let resp = alert.runModal()
            if resp == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "https://dkxuanye.cn")!)
            } else {
                NSApp.terminate(nil)
            }
        case .networkError:
            let alert = NSAlert()
            alert.messageText = "无法连接到更新服务器"
            alert.informativeText = "请检查网络连接后重试。"
            alert.addButton(withTitle: "重试")
            alert.addButton(withTitle: "退出程序")
            alert.addButton(withTitle: "继续使用")
            let resp = alert.runModal()
            switch resp {
            case .alertFirstButtonReturn: UpdateChecker.shared.checkForUpdate(completion: completion)
            case .alertSecondButtonReturn: NSApp.terminate(nil)
            default: break  // 继续使用，啥都不做
            }
        }
      }
```

### 关键技术决策

| 项 | 选择 | 理由 |
|---|---|---|
| 版本号源 | `CFBundleShortVersionString` | update.json 是 marketing version 格式（"1.0.1"） |
| 版本比较 | 字符串等值比较 | 极简档无语义化版本，避免引入版本解析库 |
| HTTP 请求 | `URLSession.shared.dataTask` | 系统自带，无需额外依赖 |
| 超时 | 15 秒 | 既能容忍慢网，又不阻塞用户太久 |
| 跳转方式 | `NSWorkspace.shared.open(URL)` | macOS 标准做法，调起默认浏览器，不嵌 webview |
| 弹窗 API | `NSAlert.runModal()` | AppKit 原生，跟现有 UI 风格一致 |
| 检查时机 | `applicationDidFinishLaunching` 末尾，**主窗口显示后** | 主窗口先出来给用户视觉反馈，弹窗随后 |
| 解析失败处理 | 视为过期 | 保守策略，宁可多弹一次也别漏掉更新 |
| 强制最低版本 | 不实现 | 极简档无此字段 |
| 签名校验 | 不实现 | 极简档无此字段 |
| 跳过机制 | 不实现 | 用户没要求"开发版本跳过"功能 |
| 国际化 | 文案走 `L10n` + `zh-Hans.lproj` | 跟现有项目风格一致，强制简体中文 |

### 弹窗文案

**升级提示（过期）**：

```
发现新版本
当前版本：{current}
最新版本：{remote}

是否前往下载页更新？

[前往更新]  [退出程序]
```

> ⚠️ **强制退出策略**：「前往更新」按钮会先打开浏览器，**然后无条件 `NSApp.terminate(nil)`**。
> 不允许用户停留在旧版本上：点完"前往更新"关闭浏览器后还能继续用旧版本，等于整个更新检查白做。
> "退出程序"按钮直接终止。结果上两个按钮行为一致（都退出），但文案保留双按钮让用户心理预期清楚。

**网络失败**：

```
无法连接到更新服务器
请检查网络连接后重试。

[重试]  [退出程序]  [继续使用]
```

> 网络失败时**不强制退出**（用户可能只是临时断网，不该被卡死）。"重试"会重新发起请求，
> "退出程序"显式退出，"继续使用"静默放行本次会话。

### 错误处理

| 错误 | 处理 |
|---|---|
| DNS 失败 / 连接超时 | `.networkError("...")`，弹网络失败窗 |
| HTTP 4xx/5xx | `.networkError("HTTP \(statusCode)")` |
| JSON 解析失败 / 字段缺失 | `.outdated(remote: "")`，弹升级窗（保守） |
| Bundle 读不到版本号 | 不检查，直接放行（启动不能因为这事挂掉） |

### 测试

单元测试 `UpdateCheckerTests.swift`，使用 `URLProtocol` mock：

| 测试用例 | 断言 |
|---|---|
| `test_currentVersion_whenRemoteMatches_callsCurrent` | 返回 `.current` |
| `test_currentVersion_whenRemoteDiffers_callsOutdated` | 返回 `.outdated(remote: "1.0.1")` |
| `test_currentVersion_whenNetworkFails_callsNetworkError` | 返回 `.networkError`，含原因 |
| `test_currentVersion_whenJSONMissing_callsOutdated` | 返回 `.outdated(remote: "")` |
| `test_currentVersion_whenVersionFieldEmpty_callsOutdated` | 同上 |
| `test_currentVersion_usesCFBundleShortVersionString_byDefault` | 不传 currentVersion 时从 bundle 读 |

测试用 mock URLProtocol 拦截网络请求，避免真实联网。

### 风险

1. **远端挂掉**：每次启动要等 15 秒超时，对用户体验略差。可后续加"24 小时内已检查过则跳过"的缓存优化，但当前不做。
2. **解析失败弹升级窗**：如果远端 JSON 写错（比如作者误删了 `version` 字段），所有用户都会看到升级窗。保守策略的代价，但作者控制远端，风险可控。
3. **无签名校验**：理论上有人能伪造 https://www.dkxuanye.fit 服务器返回假 JSON 引导用户访问钓鱼站。极简档不接受风险，需要安全时可升级到"标准"档加签名。

### 替代方案（已否决）

| 方案 | 否决理由 |
|---|---|
| 自定义协议 / Trusted Timestamp | YAGNI |
| Sparkle 框架 | 重量级，对 1 个字段的版本检查过度 |
| App Store / Sparkle 自动更新 | 用户没要 App Store 分发 |
| 把版本号塞到 UserDefaults 让用户跳过检查 | 没要求跳过机制 |
| `wkwebview` 内嵌 dkxuanye.cn | macOS 标准做法是调起浏览器，避免在 App 内嵌 |

---

## 实施步骤（概要）

1. 新增 `UpdateChecker.swift`，实现 `checkForUpdate` 方法
2. 在 `AppDelegate.applicationDidFinishLaunching` 末尾调用
3. 补充 `zh-Hans.lproj/Localizable.strings` 和 `en.lproj/Localizable.strings` 文案
4. 新增 `UpdateCheckerTests.swift`，覆盖 6 个测试用例
5. 更新 `docs/ARCHITECTURE.md`、`HANDOFF.md`、`DEV_LOG.md`、`TODO.md`
6. 跑测试验证：33 → 39 项
7. clean Release 构建验证

## 验收标准

- [ ] `UpdateChecker.shared.checkForUpdate()` 在 `applicationDidFinishLaunching` 末尾被调用
- [ ] 6 个单元测试全部通过
- [ ] 本地版本与远端一致时，应用正常启动无弹窗
- [ ] 本地版本与远端不一致时，弹升级窗，"前往更新"调起浏览器打开 dkxuanye.cn，"退出程序"终止 App
- [ ] 网络失败时，弹网络失败窗，"重试"重新检查，"退出程序"终止，"继续使用"放行
- [ ] clean Release 构建成功，签名校验通过