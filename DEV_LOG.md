# DEV_LOG.md - 开发日志

## 2026-07-08 18:15 +0800 - 发布应用图标相关更改

### 发布结果

- 工作区无未提交源码改动后，将 `main` 直接推送至私有远端 `private/main`。
- 推送内容包含关于窗口版权署名、主窗口感叹号入口、专用 AppIcon、回归测试和交接文档。
- 未创建 Pull Request；这是用户明确要求的 `main` 直接推送流程。
- 根目录 `EraseA12.app`、构建目录、截图和日志继续由忽略规则排除，没有进入提交。
- 发布前最新验证仍为 33/33 测试通过、clean Release 构建成功、严格签名和 universal 架构通过。
- 未连接或擦除任何真机。

## 2026-07-08 17:38 +0800 - EraseA12 专用应用图标

### 设计与实现

- 采用已确认的“设备轮廓 + 横向清除光带”方案：深石墨圆角底板、银白设备轮廓、
  电光蓝扫描线和一个暖红状态点，不包含文字、Apple 标志或具体设备商标。
- 从同一张 1024×1024 母版生成 macOS 16、32、128、256、512 点的 1x/2x 共 10 个 PNG。
- 新增 `AppIcon.appiconset/Contents.json`，并在 `project.yml` 指定
  `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`。
- 新增源代码树回归测试，检查 10 个槽位、文件存在性、PNG 解码和实际像素尺寸。
- “关于 EraseA12”继续读取系统应用图标，无需额外复制资源或修改窗口逻辑。

### 测试与构建

- 按 TDD 先确认资产目录缺失时聚焦测试失败，再生成和接入全部图标资产。
- 聚焦 AppIcon 测试通过；完整测试为 33/33 通过，0 失败。
- clean Release 构建成功，bundle 含 `CFBundleIconFile=AppIcon`、`CFBundleIconName=AppIcon`、
  `AppIcon.icns` 和 `Assets.car`。
- 严格签名、`x86_64 + arm64`、11 份 iBEC 和中英文字符串表检查通过。
- 实际启动 Release 应用并打开关于窗口，新图标显示清楚，现有版权与开发者署名未受影响。
- 合并到 `main` 后重新完成 33 项测试、clean Release 构建、签名、图标元数据和资源检查。
- 主目录 Release 可执行文件 SHA-256：`52768c1c9c7dc07f75aa855918c1e91f0cc6eaaf513f8b44841c092832b9b2d5`。
- 未连接或擦除任何真机。

### 仍存在的限制

- OpenSSL 动态依赖及最低系统版本链接警告仍存在，跨机器分发限制未解决。

## 2026-07-08 16:42 +0800 - 补充主窗口可见的关于按钮

### 根因与修复

- 上一版设计明确选择了仅菜单栏入口，导致主窗口没有用户期望的感叹号按钮。
- 在主窗口右上角增加 28×28 圆形 `!` 按钮，顶部约 14 点、右侧 16 点，并避开步骤指示器。
- 按钮 tooltip 和辅助功能标签均为 `关于 EraseA12`。
- `MainWindowController` 只发出 `onShowAbout` 回调；`AppDelegate` 继续负责显示和持有关于窗口。
- 原有 `EraseA12 → 关于 EraseA12` 菜单入口继续保留。

### 测试与构建

- 按 TDD 先确认缺少 `onShowAbout` 时聚焦测试编译失败，再完成最小实现。
- 新增 2 项按钮可见性、位置和点击回归测试；完整测试为 32/32 通过。
- clean Release 构建、严格签名、`x86_64 + arm64` 和 11 份 iBEC 检查通过。
- 新构建已独立启动，并通过实际窗口截图确认圆形 `!` 可见且不遮挡步骤指示器。
- 合并到 `main` 后重新完成 32 项测试、clean Release 构建和主窗口截图检查。
- 最终根目录可执行文件 SHA-256：`fca3e47dbb97f36a477c8c348c515070fc8ef77073a9e009ac132c87f9f4fd38`。
- 未连接或擦除任何真机。

### 仍存在的限制

- OpenSSL 动态依赖及其架构、最低系统版本链接警告仍存在，跨机器分发限制未解决。

## 2026-07-08 15:36 +0800 - 关于窗口与版权署名

### 最近修改

- 增加标准 `EraseA12 → 关于 EraseA12` 应用菜单。
- 增加独立 AppKit 关于窗口，版本号和构建号从 bundle 元数据读取。
- 显示原项目作者 `overcast302`、原项目 GitHub、MIT 版权和许可证信息。
- 显示 `由 玄烨品果开发`，并提供可点击的 `https://www.dkxuanye.cn` 链接。
- 中英文字符串表新增关于窗口和退出菜单文案；实际界面继续固定使用简体中文。
- `LICENSE` 原本已包含 `Copyright (c) 2026 overcast302`，因此未改写许可证正文。

### 测试与构建

- 按 TDD 先确认关于类型和菜单方法缺失时测试失败，再完成最小实现。
- 新增 4 项回归测试，完整测试从 26 项增至 30 项；30/30 通过。
- clean Release 构建成功，严格签名、`x86_64 + arm64`、11 份 iBEC 和运行启动检查通过。
- 合并到 `main` 后重新完成完整测试、clean Release 构建和独立运行检查。
- 最终根目录可执行文件 SHA-256：`37f016f69847aefee7fe2c33a9fdcfb3ef4217c737908073ab29cc4c1976ca3f`。
- 未连接或擦除任何真机。

### 仍存在的限制

- Homebrew `xcodegen` 安装因访问 GitHub formula 超时而中止；本次不新增源文件，未修改工程成员关系。
- OpenSSL 动态依赖及其架构、最低系统版本链接警告仍存在，跨机器分发限制未解决。

## 2026-07-08 15:02 +0800 - clean Release 复编译

### 执行结果

- 完整 Xcode 测试通过：26 项通过，0 失败。
- 执行 clean Release 构建，重新生成仓库根目录 `EraseA12.app`。
- 严格签名校验通过；可执行文件为 `x86_64 + arm64` universal binary。
- 中英文字符串表通过语法检查，App 内包含 11 份 patched iBEC。
- 可执行文件 SHA-256：`55d5f0f2e62386e5c2c13b625c133e9cd7e6f046158ff65183c993a520afe4c9`。

### 仍存在的发布限制

- 链接阶段仍报告 OpenSSL 架构和最低系统版本警告；最终二进制继续引用
  `/usr/local/opt/openssl@3/lib/libssl.3.dylib` 和 `libcrypto.3.dylib`，跨机器分发问题未解决。

## 2026-07-08 12:27 +0800 - 中文界面、布局修复与发布交接

### 最近修改

- 修复顶部四步指示器标题被裁切、末端标题越界和等待页内容偏移问题。
- 引入 `L10n` 并强制读取简体中文资源，覆盖等待、确认、执行、完成和错误状态。
- 补齐中英文字符串键，保留英文资源作为数据完整性和后续维护参考。
- iBEC 查找增加 bundle 根资源回退，兼容 Xcode 把资源目录扁平化的构建结果。
- 新增 8 项 UI/本地化回归测试；与原有 18 项合计 26 项。
- 更新 README 的语言说明和 OpenSSL 打包限制。
- 新增交接文档并忽略根目录构建产物。

### 重要决策

- 按用户要求，应用界面不再跟随系统语言，统一显示简体中文。
- 技术标识 `EraseA12`、`PWND`、`DFU`、`iBEC`、`CPID`、`BDID` 保留原文。
- `EraseA12/project.yml` 是工程配置源；`EraseA12.xcodeproj` 继续保持忽略。
- Release 产物只作为本地交付物，不进入源码提交。

### 涉及文件

- `EraseA12/EraseA12/App/Localization.swift`: 简体中文 bundle 读取和格式化入口。
- `EraseA12/EraseA12/UI/*.swift`: 中文文案接入与布局修复。
- `EraseA12/EraseA12/Core/ObliterationError.swift`: 用户错误信息中文化。
- `EraseA12/EraseA12/Bridge/LibirecoveryBridge.swift`: libirecovery 错误中文化。
- `EraseA12/EraseA12/Core/IBECResolver.swift`: 兼容扁平化资源目录。
- `EraseA12/EraseA12/Resources/*/Localizable.strings`: 补齐文案键。
- `EraseA12/EraseA12Tests/StepIndicatorViewTests.swift`: 中文和布局回归测试。
- `AGENTS.md`、`HANDOFF.md`、`TODO.md`、`docs/ARCHITECTURE.md`: 项目连续性资料。

### 风险和问题

- 最终可执行文件仍动态链接 `/usr/local/opt/openssl@3`，跨机器分发尚不可靠。
- 真机擦除具有破坏性，尚未执行端到端验证。
- 当前 GitHub Actions 不覆盖原生 macOS App。

### 测试情况

- 2026-07-08 12:26 完整 Xcode 测试：26 项通过，0 失败。
- Release 构建成功，产物为 `x86_64 + arm64` universal app，包含 11 份 iBEC。
- `codesign --verify --deep --strict`、字符串表语法和 `git diff --check` 均通过。
- 敏感信息扫描无命中；`otool -L` 再次确认 OpenSSL 动态依赖仍存在。

### 下一次开发建议

先解决 OpenSSL 分发依赖，再在干净克隆环境验证 xcodegen 重建，最后安排受控真机测试。
