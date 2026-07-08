# HANDOFF.md - 项目交接

**最后更新时间**: 2026-07-08 21:35 +0800

## 当前项目目标

在原有 Python/PyQt5 `usbobliter8` 工具旁提供原生 macOS 应用 EraseA12。应用识别已进入
PWND DFU 的 A12/A13 设备，上传匹配的 patched iBEC，并触发系统擦除流程。

## 当前正在做什么

为 EraseA12 增加**联网版本验证**功能，避免应用退化成单机版。启动时
`applicationDidFinishLaunching` 末尾异步 GET `https://www.dkxuanye.fit/EraseA12/update.json`，
与本地 `CFBundleShortVersionString` 比较。版本一致静默放行；不一致弹窗"前往 dkxuanye.cn 更新 / 退出程序"；
网络失败弹窗"重试 / 退出程序 / 继续使用"。通过 mock URLProtocol 单元测试 + clean Release
构建验证。

## 已完成内容

- Swift + AppKit 四步向导：连接、确认、擦除、完成。
- IOKit 监听 Apple DFU 设备，解析 `CPID`、`BDID`、`ECID` 和 `PWND` 标记。
- `Devices.plist` 配置驱动，内含 11 份 A12/A13 iBEC 资源。
- libirecovery Swift 桥接与后台擦除状态机。
- iBEC 查找兼容 `Resources/boot/` 和 Xcode 扁平化后的 `Resources/`。
- 修复步骤标题边界、横向留白和等待页垂直布局，避免文字裁切或重叠。
- 新增 `L10n`，强制从 `zh-Hans.lproj` 读取用户可见文案。
- 新增界面中文、布局和关于窗口回归测试；当前完整测试基线为 33 项。
- Release 应用已输出到仓库根目录并进行 ad-hoc 签名。
- 2026-07-08 15:02 clean Release 复编译：26/26 测试通过，严格签名、universal 架构和 11 份 iBEC 资源检查通过。
- 增加 `EraseA12 → 关于 EraseA12` 菜单和独立关于窗口。
- 关于窗口显示原项目作者 `overcast302`、`Copyright © 2026 overcast302`、`MIT License`、
  `由 玄烨品果开发` 和可点击的 `www.dkxuanye.cn`。
- 2026-07-08 15:36 主分支验证：30/30 测试、clean Release、严格签名、universal 架构、资源和实际启动通过。
- 修复主窗口缺少可见入口的问题：右上角增加 28×28 圆形 `!` 按钮，辅助标签为
  `关于 EraseA12`，通过 `onShowAbout` 回调打开现有关于窗口。
- 2026-07-08 16:42 主分支验证：32/32 测试、clean Release、严格签名、universal 架构、资源、
  实际启动、关于窗口和主窗口截图检查通过。
- 增加完整 `AppIcon.appiconset`，包含 macOS 16、32、128、256、512 点的 1x/2x 共 10 个 PNG，
  并在 `project.yml` 指定 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`。
- 新增 AppIcon 槽位、文件和像素尺寸回归测试；完整测试基线更新为 33 项。
- 2026-07-08 17:58 主分支验证：33/33 测试、clean Release、严格签名、universal 架构、
  `AppIcon.icns`、`Assets.car`、11 份 iBEC 和实际关于窗口图标检查通过。
- 2026-07-08 18:15 应用户要求将关于窗口、可见感叹号按钮和应用图标等本地提交直接推送至
  私有远端 `private/main`；本地 `EraseA12.app` 等生成物仍保持忽略且未提交。
- 新增 `Scripts/make-dmg-background.swift`：用 Swift + Core Graphics 绘制 540×360
  DMG 背景图（暗色渐变 + 应用图标占位 + 横向箭头 + Applications 文件夹占位 +
  "安装 EraseA12" 标题 + 底部首次打开提示），可直接 `swift make-dmg-background.swift` 运行。
- 改进 `Scripts/package-dmg.sh`：clean Release → ad-hoc 签名 → 生成背景图 → 准备
  staging（含 `.background/`、Applications 符号链接、《打开方式.txt》）→ 挂载中间态 UDRW
  → AppleScript 让 Finder 自动配置图标视图、背景图、图标位置、窗口大小 →
  生成 `.DS_Store` → 转 UDZO 压缩 DMG。GUI 环境开箱即用，无 GUI 环境 fallback 到无
  `.DS_Store` 版本。`SKIP_DMG_FINDER_LAYOUT=1` 可跳过 Finder 步骤。
- 2026-07-08 18:39 DMG 打包验证：14M、UDZO、`.DS_Store`（10244 字节）含
  `backgroundImageAlias` 引用 `dmg-background.png`，挂载实测 Finder 自动应用背景图
  显示安装指引。
- 新增 `EraseA12/App/UpdateChecker.swift`：启动时联网版本验证单例，URLSession + Codable，
  15 秒超时，主线程回调；`UpdateResult` 三态枚举（current / outdated / networkError）。
- 新增 `EraseA12Tests/UpdateCheckerTests.swift`：6 项测试覆盖版本一致/不一致/网络失败/
  JSON 缺字段/字段为空/默认从 bundle 读 CFBundleShortVersionString，用 `MockURLProtocol` 拦截请求。
- `AppDelegate.applicationDidFinishLaunching` 末尾调用 `UpdateChecker.shared.checkForUpdate()`，
  主窗口显示后再异步检查，结果分两套弹窗（升级提示 / 网络失败重试）通过 `NSAlert.runModal`。
- 补充 `zh-Hans.lproj` 和 `en.lproj` 共 8 个新文案 key（`update.outdated_title`、`update.outdated_body`、
  `update.network_error_title`、`update.network_error_body`、`update.action.open/quit/retry/continue`）。
- 设计文档：`docs/superpowers/specs/2026-07-08-erasea12-update-checker-design.md`（已 commit）。
- 2026-07-08 21:35 验证：39/39 测试通过（新增 6 项），clean Release 构建成功，严格签名通过，
  universal binary `x86_64 + arm64`，SHA-256 `1db3732399870217c2b5f2fb71e5c909264b83c541d0e0e754b1c49b70ca9e85`。

## 未完成内容

- 尚未在受控真机上完成从 PWND DFU 到设备开始擦除的端到端验证。
- 尚未消除最终二进制对 Homebrew OpenSSL 动态库的依赖。
- 原生 EraseA12 尚未接入 GitHub Actions；现有工作流只构建 Python 版本。
- 未做 Developer ID 签名和 Apple 公证，当前仅适合私人测试分发。

## 当前已知问题

- `EraseA12.app/Contents/MacOS/EraseA12` 仍引用
  `/usr/local/opt/openssl@3/lib/libssl.3.dylib` 和 `libcrypto.3.dylib`。在没有相同路径的 Mac 上
  可能无法启动。
- `EraseA12.xcodeproj` 按设计被忽略；干净克隆后需要先安装 xcodegen 并从
  `EraseA12/project.yml` 生成工程。`package-dmg.sh` 已兼容未装 xcodegen 但本地已有
  `EraseA12.xcodeproj` 的情况。
- 当前设计文档仍保留早期“跟随系统语言”的描述；实际实现已按用户要求固定简体中文。

## 当前风险

- 擦除命令不可逆，自动化测试只覆盖识别、解析、状态机和 UI，不覆盖真实数据擦除结果。
- ad-hoc 签名无法替代 Developer ID 签名与公证，其他 Mac 首次打开会受到 Gatekeeper 限制。
- 本机生成的 Xcode 工程是忽略文件；新增 Swift 文件时必须确保 `project.yml` 可重新生成同等工程。
- DMG `.DS_Store` 由 Finder 在挂载中产生，跨 macOS 大版本可能需要重新生成；CI/无 GUI
  环境打包出的 DMG 不含 `.DS_Store`，用户需手动在 Finder 里选择"查看显示选项 → 背景 → 图片"。

## 下一步建议

1. 优先把 OpenSSL 改为可随应用分发的 universal 静态链接或正确嵌入并重签名。
2. 在干净环境安装 xcodegen，从 `project.yml` 重建工程并复跑 33 项测试及 Release 构建。
3. 使用可清空的测试设备做一次受控真机端到端验证，记录每个状态转换和最终设备状态。
4. 为原生 App 增加独立 CI 构建与单元测试任务，把 DMG 打包和 UpdateChecker 联网测试纳入 CI。
5. 后续可考虑把 `.DS_Store` 模板提取并固化到仓库，CI 环境也能直接复用，避免每次依赖 GUI。
6. 把 update.json 部署到 `https://www.dkxuanye.fit/EraseA12/update.json`，首次发版用 `1.0.0`。

## 新会话优先查看的文件

1. `EraseA12/project.yml` - 构建配置、资源和链接依赖的标准来源。
2. `EraseA12/EraseA12/Core/ObliterationEngine.swift` - 破坏性擦除主流程。
3. `EraseA12/EraseA12/Core/IBECResolver.swift` - iBEC 资源查找和 Xcode 扁平化兼容。
4. `EraseA12/EraseA12/UI/MainWindowController.swift` - 四步向导和右上角关于按钮。
5. `EraseA12/EraseA12/App/AppDelegate.swift` - 应用菜单、关于窗口、按钮回调、**联网更新检查**和应用生命周期。
6. `EraseA12/EraseA12/App/Localization.swift` - 固定简体中文的实现入口。
7. `EraseA12/EraseA12/App/UpdateChecker.swift` - 联网版本验证单例（15 秒超时，主线程回调）。
8. `EraseA12/EraseA12Tests/StepIndicatorViewTests.swift` - 中文界面、布局和关于入口回归测试。
9. `EraseA12/EraseA12Tests/UpdateCheckerTests.swift` - 联网更新检查 6 项测试（MockURLProtocol）。
10. `EraseA12/EraseA12/Resources/Assets.xcassets/AppIcon.appiconset/` - 应用图标的 10 个标准槽位。
11. `EraseA12/Scripts/make-dmg-background.swift` - DMG 背景图生成脚本。
12. `EraseA12/Scripts/dmg-background.png` - 已生成的背景图（如有则跳过生成）。
13. `EraseA12/Scripts/package-dmg.sh` - DMG 打包主脚本。
14. `docs/superpowers/specs/2026-07-08-erasea12-update-checker-design.md` - 联网更新检查设计文档。

## 禁止做的事情

- 不要在没有明确授权和受控测试设备的情况下执行真机擦除。
- 不要把本机构建产物、截图、日志或 `.DS_Store` 提交到仓库（DMG staging 中的中间
  `.DS_Store` 已经被脚本清理，不会进源码）。
- 不要把 OpenSSL 动态依赖问题误写成“应用完全无外部依赖”。
- 不要手工长期维护被忽略的 Xcode 工程而不同步 `project.yml`。
