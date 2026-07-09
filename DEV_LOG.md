# DEV_LOG.md - 开发日志

## 2026-07-09 11:30 +0800 - vendor 体积瘦身：移除 OpenSSL .a 静态库

### 用户反馈

> "1"（在"vendor 瘦身"选项）

### 改动

- `.gitignore` 加 `EraseA12/Vendor/openssl/lib/*.a` 规则。
- `git rm --cached EraseA12/Vendor/openssl/lib/libssl.a libcrypto.a` 从索引移除（工作树保留）。
- 工作树里的 `libssl.a` (2.9 MB) 和 `libcrypto.a` (17 MB) 仍存在供本地 build 备用，
  `git status` 不再显示。

### 为什么 .a 是安全的

- `Scripts/bundle-openssl.sh` 只拷贝 `.dylib` 到 `Contents/Frameworks/`，从不动 `.a`。
- `EraseA12/project.yml` 不引用 `Vendor/openssl/`，OpenSSL 链接走的是
  `bundle-openssl.sh` 在打包阶段注入的 `@rpath/...dylib`。
- 源码 grep `libssl|libcrypto` 没有静态引用 `.a`。

### 验证

- `git check-ignore -v libssl.a libcrypto.a` 两文件都命中规则。
- `SKIP_DMG_FINDER_LAYOUT=1 ./Scripts/package-dmg.sh` 完整跑通：
  - clean Release 构建成功
  - ad-hoc 严格签名通过
  - OpenSSL dylib 嵌入成功，`@rpath/libssl/libcrypto.3.dylib`
  - DMG 19M、SHA-256 `e6f5e85ddb3ec557c45e693e8fb1c6c9227a6f1d4eaeda7a1da36dcddc21b6e3`
  - `.background/`、Applications 符号链接、EraseA12.app 全部齐全

### 发现的连带问题

`EraseA12/Makefile` 的 `release` 和 `dmg` 目标硬依赖 `xcodegen generate`，但本机未装
（之前 Homebrew 安装因 GitHub formula 超时中止）。`Scripts/package-dmg.sh` 本身已兼容
无 xcodegen + 本地已有 `.xcodeproj` 的 fallback，所以这次直接调脚本完成验证。
Makefile 的硬依赖应该改为可选：xcodegen 缺失时跳过 generate，直接调 `package-dmg.sh`。
（已加入 HANDOFF 下一步建议，待用户决策是否现在修。）

### 仍存在的限制

- DMG 仍为 ad-hoc 签名，需要 Developer ID + Apple 公证才能跨机器免 Gatekeeper 警告。
- 干净克隆下未用 xcodegen 重建 + 跑测试（受本机 xcodegen 缺失阻塞）。
- 未连接或擦除任何真机。

## 2026-07-09 09:56 +0800 - 推送 OpenSSL 集成 + 文档同步

### 用户反馈

> "更新项目交接文件，提交更改并推送"

### 推送结果

- `e4aa9b8 feat(openssl): 集成 universal OpenSSL 3.6.2，应用自包含可分发` — 154 files, +46526/-17
- `5b5036c feat: 联网更新检查 + 可视化 DMG 打包`
- `77b2d99 docs(spec): EraseA12 联网更新检查设计文档`

`private/main` 远端现在包含完整的自包含 OpenSSL 集成链路：
build → bundle → DMG 嵌入 → 重签名。

### vendor 体积讨论

| 文件 | 大小 | 是否 DMG 必须 |
|---|---|---|
| `libcrypto.3.dylib` | 10.4 MB | ✅ 嵌入 Frameworks/ |
| `libssl.3.dylib` | 2.0 MB | ✅ 嵌入 Frameworks/ |
| `include/openssl/*.h` | ~1.4 MB | ❌ 仅编译期 |
| `libcrypto.a` | 17.8 MB | ❌ 备用（不嵌入 DMG） |
| `libssl.a` | 3.0 MB | ❌ 备用（不嵌入 DMG） |
| **vendor 总计** | **~34 MB** | |

DMG 实际只用 12.4 MB 的两个 dylib。`.a` 静态库是 `build-openssl.sh` 编译时一起产的
（跟 `libirecovery.a` 一致进 vendor）。如果嫌 34 MB vendor 太大，可以加
`.gitignore` 排除 `Vendor/openssl/lib/*.a`，仅保留 dylib + 头文件，待用户决定。

### 仍存在的限制

- DMG 仍为 ad-hoc 签名，需要 Developer ID + Apple 公证才能跨机器免 Gatekeeper 警告。
- vendor 体积优化决策待用户确认。
- 未连接或擦除任何真机。

## 2026-07-08 22:08 +0800 - 集成 OpenSSL dylib，开箱即用

### 用户反馈

> "你要集成 OpenSSL 动态依赖，做到别人可以开箱即用"

### 背景

之前 EraseA12 二进制动态链接 `/usr/local/opt/openssl@3/lib/libssl.3.dylib`，
在没有 Homebrew OpenSSL 的 Mac 上启动会失败（dlopen 找不到库）。
系统 OpenSSL dylib 只有 x86_64，没有 arm64，跟 EraseA12 的 universal binary 不匹配。

### 实现

- **新增 `Scripts/build-openssl.sh`**：从 openssl.org 下载 OpenSSL 3.6.2 源码，
  分别用 `darwin64-x86_64-cc` 和 `darwin64-arm64-cc` 配置编译两遍：
  - 第一遍 `no-shared` → universal 静态库 `.a`（备用）
  - 第二遍 `shared` → universal 动态库 `.dylib`
  - `lipo -create` 合成 `libssl.3.dylib`（2.0M）和 `libcrypto.3.dylib`（10.5M）
  - 产物：`EraseA12/Vendor/openssl/lib/` + `EraseA12/Vendor/openssl/include/openssl/`
  - 编译耗时约 8 分钟（带 -j 多核）
- **新增 `Scripts/bundle-openssl.sh`**：把 universal dylib 嵌入 `.app/Contents/Frameworks/`：
  1. 拷贝 `libssl.3.dylib` / `libcrypto.3.dylib` 到 Frameworks/
  2. `install_name_tool -id @rpath/libssl.3.dylib` 改 dylib 自身 install name
  3. `install_name_tool -change` 改 libssl 内部对 libcrypto 的引用
  4. `install_name_tool -add_rpath @executable_path/../Frameworks` 给可执行加 RPATH
  5. `install_name_tool -change` 改 EraseA12 二进制对 libssl/libcrypto 的引用
  6. 重新签名（dylib 先签，app 后签）
- **改 `Scripts/package-dmg.sh`**：在 `[2/6] ad-hoc 签名` 之后插入 `[2.5/6] 嵌入 OpenSSL dylib`。
  关键坑：之前想在 `[0/6]` 嵌入，但 `xcodebuild clean build` 会删 build 目录，
  把刚嵌入的 Frameworks/ 一起清掉。必须放在 build+sign 之后、staging 之前。

### 测试与构建

- 编译前：otool -L 显示依赖 `/usr/local/opt/openssl@3/...`（无法分发）
- 编译后：otool -L 显示依赖 `@rpath/libssl.3.dylib` / `@rpath/libcrypto.3.dylib`
- `otool -l` 验证 LC_RPATH 含 `@executable_path/../Frameworks`
- 严格签名通过：两个 dylib + app 全部 `--prepared/--validated`
- DMG 19M（之前 14M + 5M OpenSSL）
- 39/39 测试通过（OpenSSL 嵌入不影响功能）
- DMG SHA-256 `3d09e4f797f168453198c5d02f1821247addbdfd4ffb6f0ad3f9f295b2efe9cd`

### 仍存在的限制

- DMG 仍为 ad-hoc 签名，需要 Developer ID + Apple 公证才能跨机器免 Gatekeeper 警告
- 没用 OpenSSL FIPS 模块

## 2026-07-08 21:50 +0800 - "编译 = 打 DMG" 流程固化

### 用户反馈

> "你怎么没有打包 dmg，下次我让你编译 APP，就要顺带打包 dmg"

### 改动

- `EraseA12/Makefile` 新增 `release` 和 `dmg` 一键目标，调用 `Scripts/package-dmg.sh`，
  避免再次出现"只 build 不打 DMG"的情况。
- `Scripts/package-dmg.sh` 修了一个**潜在 bug**：`SKIP_DMG_FINDER_LAYOUT=1` 路径
  之前只 echo 跳过，**没有真正生成 DMG**。改为 echo 跳过 + 直接从 staging 用
  `hdiutil create -format UDZO` 生成 DMG（牺牲 .DS_Store，换取无 GUI 环境也能成功打包）。
- `AGENTS.md` 重写"EraseA12 验证基线"章节：明确"编译 APP"必须顺带打 DMG，
  主命令从 `make build` 改为 `make release`，并保留 `SKIP_DMG_FINDER_LAYOUT=1` 用法。
- 验证：跑了一次完整 `make release`（GUI 环境），产物 14M DMG，
  SHA-256 `3644b82d63594c4c1707080eecb672b7686c77996b6cac8835cc85fa7acec682`，
  含 `.background/dmg-background.png`、Applications 符号链接、EraseA12.app。

## 2026-07-08 21:35 +0800 - EraseA12 联网更新检查

### 设计与实现

- 新增 `EraseA12/App/UpdateChecker.swift`：单例 `UpdateChecker.shared`，
  `checkForUpdate(endpoint:currentVersion:completion:)` 异步联网验证版本；
  URLSession GET 远端 endpoint，15 秒超时，主线程回调；
  `UpdateResult` 枚举三态：`.current`、`.outdated(remote:)`、`.networkError(reason:)`。
- 版本对比策略：字符串等值比较 `CFBundleShortVersionString`；
  JSON 解析失败 / `version` 字段缺失 / 字段为空字符串 → 视为过期（保守策略）；
  HTTP 非 2xx / 网络层 error → 视为网络错误。
- `AppDelegate.applicationDidFinishLaunching` 末尾调用 `checkForAppUpdate()`，
  主窗口显示后**异步**启动，不阻塞 UI。
- 两套 NSAlert：
  - 升级窗：`发现新版本`（当前 X / 最新 Y / 是否前往更新），
    「前往更新」→ `NSWorkspace.shared.open("https://dkxuanye.cn")`，
    「退出程序」→ `NSApp.terminate(nil)`。
  - 网络失败窗：`无法连接到更新服务器`，
    「重试」→ 重新调用 `checkForAppUpdate()`，
    「退出程序」→ `NSApp.terminate(nil)`，
    「继续使用」→ 静默放行。
- 中英文 `Localizable.strings` 新增 8 个文案 key，强制中文（`L10n` 走 `zh-Hans.lproj`）。

### 测试与构建

- 按 TDD 流程：先写 `UpdateCheckerTests.swift` 6 个用例（用 `MockURLProtocol` 拦截请求），
  编译失败（红）→ 实现 `UpdateChecker.swift`（绿）。
- 完整测试 39/39 通过：DeviceIdentifierTests 8、IBECResolverTests 6、ObliterationEngineTests 4、
  StepIndicatorViewTests 15、UpdateCheckerTests 6。
- clean Release 构建成功，ad-hoc 严格签名通过，`x86_64 + arm64` universal。
- 主目录可执行 SHA-256：`1db3732399870217c2b5f2fb71e5c909264b83c541d0e0e754b1c49b70ca9e85`。
- 未做真机擦除；未连接 `https://www.dkxuanye.fit` 验证真实响应（设计阶段已说明：单测覆盖所有代码路径）。

### 仍存在的限制

- pbxproj 是被忽略的本地生成文件，**新增的 UpdateChecker.swift 和 UpdateCheckerTests.swift
  必须用 xcodegen 重新生成 pbxproj**；当前是手动 patch，等装好 xcodegen 后用 `xcodegen generate` 覆盖。
- UpdateChecker 启动时每次都联网请求；远端挂掉时用户体验是 15 秒超时。
  可后续加"24 小时内已检查过则跳过"的缓存。
- 没有强最低版本（minVersion）和签名校验，需要时升级到"标准"档。

## 2026-07-08 18:40 +0800 - 可视化 DMG 打包流程

### 设计与实现

- 新增 `Scripts/make-dmg-background.swift`：纯 Swift + Core Graphics，绘制 540×360
  暗色渐变背景图，包含"安装 EraseA12"标题、副标题"将 EraseA12.app 拖动到右侧
  Applications 文件夹中"、左侧应用图标占位（圆角矩形 + 设备轮廓 + 蓝色光带 + 红点）、
  中间白色粗箭头 + "拖动"、右侧 Applications 文件夹占位（带"A"图标的文件夹）、
  底部"首次打开请参考 DMG 内《打开方式.txt》"。可直接 `swift make-dmg-background.swift`
  运行，输出到同目录 `dmg-background.png`。
- 重写 `Scripts/package-dmg.sh`：
  - clean Release 构建（兼容无 xcodegen 但已有本地 `EraseA12.xcodeproj` 的场景）
  - ad-hoc 严格签名
  - 调用背景图脚本（如不存在）
  - 准备 staging 目录：`.background/dmg-background.png`、`Applications → /Applications`
    符号链接、中英文《打开方式.txt》
  - 用 UDRW 创建中间态 DMG，挂载后通过 AppleScript 让 Finder 自动配置图标视图、
    `background picture` 引用 `.background/dmg-background.png`、图标位置、窗口大小，
    让 Finder 自动生成 `.DS_Store`
  - 卸载后 `hdiutil convert` 为 UDZO 压缩 DMG
  - 挂载校验：确认 `.background/`、Applications 符号链接、EraseA12.app 都在
  - 提供 `SKIP_DMG_FINDER_LAYOUT=1` 跳过 Finder 自动化
- 挂载实测：Finder 自动应用背景图，显示完整安装指引窗口。

### 关键技术问题

- `hdiutil attach -plist` 输出是 XML plist，`plutil -convert binary1 -o -` 的 stdout 是
  binary 数据，含 NUL 字节；bash 变量赋值 `$()` 会把 NUL 当字符串结束，导致后续
  `plutil -extract` 失败。改用临时文件缓存 binary plist 解决。
- `plutil -extract` 失败时把错误信息写到 stdout（不是 stderr），需要先做退出码检查，
  否则 `MOUNT_POINT` 会被赋值为错误字符串。脚本中已加 `>/dev/null 2>&1` 探测 + 二次提取。
- `hdiutil convert -ov out.dmg in.dmg` 顺序：`hdiutil` 把 `-ov` 后面的两个文件都当成
  input，触发 "only a single input file"。正确写法 `hdiutil convert -ov -o out.dmg in.dmg`。

### 测试与构建

- clean Release 构建通过；ad-hoc 严格签名通过。
- 最终 DMG：`/Users/dkxuanye/Desktop/usbobliter8/EraseA12-1.0.0.dmg`，14M，UDZO。
- DMG SHA-256：`f784d3e4957d1a4618e37cd005fe77d8c97fc7a6de3f4f5eb7f2e34d19c3b1bd`。
- 挂载验证 `.DS_Store`（10244 字节）含 `backgroundImageAlias` 字段引用
  `.background/dmg-background.png`，Finder 实际显示安装指引窗口。
- 未连接或擦除任何真机。

### 仍存在的限制

- OpenSSL 动态依赖、Developer ID 签名与 Apple 公证仍未解决，DMG 仍只适合私人分发。
- `.DS_Store` 由本机 Finder 生成，跨 macOS 大版本可能在没有 GUI 的 CI 上失效；后续可
  提取固化到仓库。

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
