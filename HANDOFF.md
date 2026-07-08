# HANDOFF.md - 项目交接

**最后更新时间**: 2026-07-08 16:42 +0800

## 当前项目目标

在原有 Python/PyQt5 `usbobliter8` 工具旁提供原生 macOS 应用 EraseA12。应用识别已进入
PWND DFU 的 A12/A13 设备，上传匹配的 patched iBEC，并触发系统擦除流程。

## 当前正在做什么

已补上主窗口右上角始终可见的圆形 `!` 按钮，点击可打开现有“关于 EraseA12”版权窗口；
菜单入口继续保留。功能已通过测试、Release 构建和实际窗口截图检查，当前处于分支收尾阶段。

## 已完成内容

- Swift + AppKit 四步向导：连接、确认、擦除、完成。
- IOKit 监听 Apple DFU 设备，解析 `CPID`、`BDID`、`ECID` 和 `PWND` 标记。
- `Devices.plist` 配置驱动，内含 11 份 A12/A13 iBEC 资源。
- libirecovery Swift 桥接与后台擦除状态机。
- iBEC 查找兼容 `Resources/boot/` 和 Xcode 扁平化后的 `Resources/`。
- 修复步骤标题边界、横向留白和等待页垂直布局，避免文字裁切或重叠。
- 新增 `L10n`，强制从 `zh-Hans.lproj` 读取用户可见文案。
- 新增界面中文、布局和关于窗口回归测试；当前完整测试基线为 32 项。
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
  `EraseA12/project.yml` 生成工程。
- 当前设计文档仍保留早期“跟随系统语言”的描述；实际实现已按用户要求固定简体中文。

## 当前风险

- 擦除命令不可逆，自动化测试只覆盖识别、解析、状态机和 UI，不覆盖真实数据擦除结果。
- ad-hoc 签名无法替代 Developer ID 签名与公证，其他 Mac 首次打开会受到 Gatekeeper 限制。
- 本机生成的 Xcode 工程是忽略文件；新增 Swift 文件时必须确保 `project.yml` 可重新生成同等工程。

## 下一步建议

1. 优先把 OpenSSL 改为可随应用分发的 universal 静态链接或正确嵌入并重签名。
2. 在干净环境安装 xcodegen，从 `project.yml` 重建工程并复跑 32 项测试及 Release 构建。
3. 使用可清空的测试设备做一次受控真机端到端验证，记录每个状态转换和最终设备状态。
4. 为原生 App 增加独立 CI 构建与单元测试任务。

## 新会话优先查看的文件

1. `EraseA12/project.yml` - 构建配置、资源和链接依赖的标准来源。
2. `EraseA12/EraseA12/Core/ObliterationEngine.swift` - 破坏性擦除主流程。
3. `EraseA12/EraseA12/Core/IBECResolver.swift` - iBEC 资源查找和 Xcode 扁平化兼容。
4. `EraseA12/EraseA12/UI/MainWindowController.swift` - 四步向导和右上角关于按钮。
5. `EraseA12/EraseA12/App/AppDelegate.swift` - 应用菜单、关于窗口、按钮回调和应用生命周期。
6. `EraseA12/EraseA12/App/Localization.swift` - 固定简体中文的实现入口。
7. `EraseA12/EraseA12Tests/StepIndicatorViewTests.swift` - 中文界面、布局和关于入口回归测试。

## 禁止做的事情

- 不要在没有明确授权和受控测试设备的情况下执行真机擦除。
- 不要把本机构建产物、截图、日志或 `.DS_Store` 提交到仓库。
- 不要把 OpenSSL 动态依赖问题误写成“应用完全无外部依赖”。
- 不要手工长期维护被忽略的 Xcode 工程而不同步 `project.yml`。
