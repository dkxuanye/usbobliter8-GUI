# DEV_LOG.md - 开发日志

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
