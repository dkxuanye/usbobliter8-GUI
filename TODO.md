# TODO.md - 任务清单

## P0 - 必须优先处理

- [x] 移除 `/usr/local/opt/openssl@3` 运行时依赖，改为 universal 静态链接或正确嵌入并重签名。
- [ ] 在受控且允许清空的 A12/A13 测试设备上完成一次端到端擦除验证。

## P1 - 重要任务

- [ ] 在干净克隆中安装 xcodegen，从 `project.yml` 生成工程并复跑测试与 Release 构建。
- [ ] 为 EraseA12 增加 GitHub Actions 构建和单元测试任务。
- [ ] 同步早期设计文档中“跟随系统语言”等已经变化的描述。

## P2 - 后续优化

- [ ] 配置 Developer ID 签名与 Apple 公证，减少 Gatekeeper 手工操作。
- [ ] 增加无设备、设备中途断开和恢复模式超时的 UI 自动化覆盖。
- [ ] 根据真机验证结果补充故障诊断日志，但不在主界面暴露协议细节。
- [ ] 修 `EraseA12/Makefile` 的 `release`/`dmg` 目标：xcodegen 缺失时 fallback 到
  已存在的 `EraseA12.xcodeproj`，仿照 `package-dmg.sh` 的兼容逻辑。

## Done - 已完成

- [x] 完成 Swift + AppKit 原生四步擦除向导。
- [x] 支持 11 份 A12/A13 设备配置和 iBEC 资源。
- [x] 修复步骤指示器文字裁切和等待页布局。
- [x] 全部用户可见界面固定显示简体中文。
- [x] 增加中文界面、错误文案和布局回归测试。
- [x] 生成本机 universal Release 应用并进行 ad-hoc 签名。
- [x] 2026-07-08 15:02 完成 clean Release 复编译及 26 项测试、签名、架构和资源复验。
- [x] 增加标准“关于 EraseA12”窗口，展示原作者版权、MIT License、玄烨品果署名和网站链接。
- [x] 在主窗口右上角增加圆形感叹号按钮，点击打开版权关于窗口。
- [x] 设计并接入 EraseA12 专用 macOS 应用图标，覆盖 10 个标准 AppIcon 槽位，并推送至 `private/main`。
- [x] 新增 `Scripts/make-dmg-background.swift`，用 Core Graphics 生成可视化 DMG 背景图（含“拖动到 Applications”指引）。
- [x] 改进 `Scripts/package-dmg.sh`：clean Release 构建、ad-hoc 签名、`.background/` 背景图、Applications 符号链接、用 Finder 自动配置窗口布局生成 `.DS_Store`，输出 UDZO 压缩 DMG。
- [x] 2026-07-08 18:39 完成 DMG 打包验证：14M、`.DS_Store` 含 `backgroundImageAlias` 引用背景图，挂载后 Finder 自动显示安装指引窗口。
- [x] 新增联网更新检查：App/UpdateChecker.swift + UpdateCheckerTests.swift（6 项）+ AppDelegate 集成 + 强制退出策略（避免用户绕过）。
- [x] 2026-07-08 21:35 完成 39/39 测试、clean Release 构建、严格签名、universal binary 验证。
- [x] 设计文档：`docs/superpowers/specs/2026-07-08-erasea12-update-checker-design.md` 已 commit。
- [x] 2026-07-08 21:50 "编译 = 打 DMG" 流程固化：Makefile 加 `release`/`dmg` 目标，AGENTS.md 改"验证基线"为标准，修复 package-dmg.sh SKIP 路径 bug。
- [x] 2026-07-08 22:08 集成 OpenSSL dylib：编译 universal libssl/libcrypto 3.6.2 嵌入 .app/Contents/Frameworks/，改 install name + RPATH + 重签，otool -L 不再依赖 /usr/local/opt。
- [x] 2026-07-08 22:10 自包含 DMG 验证：19M，SHA-256 `3d09e4f7...`，LC_RPATH `@executable_path/../Frameworks`，dylib 严格签名通过。
- [x] 2026-07-09 09:56 推送 OpenSSL 集成至 `private/main`（commit `e4aa9b8`，154 files,
  +46526/-17），同步更新 `HANDOFF.md` / `DEV_LOG.md` / `TODO.md`。
- [x] 2026-07-09 11:30 vendor 体积瘦身：`.gitignore` 加 `EraseA12/Vendor/openssl/lib/*.a`，
  `git rm --cached` 移除 `libssl.a` / `libcrypto.a`（共 ~21 MB），工作树保留；DMG 重新打包
  验证通过，SHA-256 `e6f5e85d...`。
