# EraseA12 设计文档

日期：2026-07-07
状态：已批准（待写实现计划）

## 背景

现有 `usbobliter8` 是一个 Python/PyQt5 工具，用于擦除 A12/A13 iOS 设备。用户需先用外部工具
`usbliter8` 让设备进入 "PWND DFU" 状态，然后运行 `usbobliter8`，点击按钮后工具上传一个
patched iBEC，触发 iOS 原生的"抹掉所有内容"擦除机制。

`EraseA12` 是把这套能力重做成原生 macOS 应用，目标是私下分发、开箱即用、无需用户安装
Python/依赖，同时具备现代化的 macOS 26 风格外观。

## 目标与非目标

**目标**
- 原生 macOS app（Swift + AppKit），无需用户安装任何运行时或依赖
- 检测设备是否已处于 PWND DFU 状态，并展示设备识别信息
- 执行与现有 Python 版本等价的擦除流程：上传 patched iBEC → boot → 发送 NVRAM 擦除指令 → 重启
- 支持 macOS 10.15 (Catalina) 到 15.5+ 全版本range，无签名证书，`.dmg` 私下分发
- 现代化 UI：macOS 26 液态玻璃（Liquid Glass）风格 + 渐变光晕效果，向下版本平滑降级
- 架构上为未来新增设备型号留出扩展空间（配置文件驱动而非硬编码）

**非目标**
- 不实现 checkm8/exploit 逻辑本身，不负责让设备进入 PWND DFU 状态（由用户使用外部工具
  `usbliter8` 完成）
- 不做批量多设备并发擦除
- 不做详细技术日志面板（仅简洁状态提示）
- 不做代码签名/公证（无证书，私下分发）

## 技术选型

| 决策点 | 选择 | 理由 |
|---|---|---|
| UI 框架 | Swift + AppKit | SwiftUI 在 10.15 上关键 API 缺失（`@StateObject`、`LazyVStack` 等需 11+），AppKit 原生支持 10.15+ 全部所需控件 |
| USB/DFU 通信 | 链接现有已编译的 `libimobiledevice`（`libirecovery`）C 库 | 用户已有成熟编译产物，通过 Swift bridging header 直接调用，避免重新实现 DFU/USB 协议 |
| 设备发现 | IOKit (`IOServiceAddMatchingNotification`) 监听 Apple DFU 设备（VID `0x05AC`, PID `0x1227`）插入/移除 | 系统原生 API，无需 polling 之外的额外依赖 |
| PWND 检测 | 通过 libirecovery 读取设备 USB serial string，检查 `PWND:[` 标记（与现有 Python 逻辑一致） | 保持与验证过的现有逻辑等价 |
| exploit 触发 | 不做 — 完全由用户手动用 `usbliter8` 完成，app 只负责检测状态 | 用户明确要求，降低风险和维护面 |
| 设备配置 | Plist（`Devices.plist`），键为 `cpid`/`bdid`，值为设备名 + iBEC 文件名 | 替代硬编码字典，方便未来加新设备无需改代码 |
| iBEC 文件管理 | 混合模式：默认内嵌于 `Resources/boot/`；同时支持用户在
  `~/Library/Application Support/EraseA12/boot/` 放置自定义文件，覆盖/补充内嵌文件 | 开箱即用 + 可扩展 |
| 分发格式 | `.dmg`，ad-hoc 签名（无付费证书） | 用户选择；README 说明如何在 Gatekeeper 下打开 |
| 本地化 | `NSLocalizedString` + `.strings`，跟随系统语言（中/英） | 双语支持 |
| 部署目标 | `MACOSX_DEPLOYMENT_TARGET = 10.15` | 覆盖要求范围 |

## 架构

```
EraseA12.app/
├── Contents/
│   ├── MacOS/EraseA12                    (Swift 可执行文件)
│   ├── Resources/
│   │   ├── boot/                         (内嵌默认 iBEC 文件，11 个)
│   │   ├── Devices.plist                 (设备型号配置表)
│   │   ├── en.lproj/Localizable.strings
│   │   └── zh-Hans.lproj/Localizable.strings
│   └── Frameworks/
│       └── libirecovery 相关 .dylib（静态或动态链接产物）
```

### 模块划分

- **`USBDeviceMonitor`**：包装 IOKit 通知，监听 DFU 设备插拔，防抖后回调上层。只负责"有没有
  设备插着"，不做协议解析。
- **`LibirecoveryBridge`**：Swift 对 libirecovery C API 的薄封装（bridging header），暴露
  `connect()`、`readSerialString()`、`uploadImage(_:)`、`sendCommand(_:)`、`reboot()` 等方法，
  内部处理 C 指针/错误码到 Swift `Result`/`Error` 的转换。
- **`DeviceIdentifier`**：解析 serial string 里的 `CPID`/`BDID`/`ECID`/`PWND:[`，查 `Devices.plist`
  得到设备名和对应 iBEC 文件名。等价于现有 Python 的 `_serial_field` + `identify`。
- **`IBECResolver`**：根据设备的 iBEC 文件名，按优先级查找文件：用户自定义目录 → app bundle
  内嵌目录。找不到则报错，按钮保持禁用。
- **`ObliterationEngine`**：驱动整个擦除流程的状态机（见下）。调用 `LibirecoveryBridge` 完成
  upload → boot → 等待 recovery 模式重新连接 → 发送三条 NVRAM 指令 → reboot。运行在后台
  `DispatchQueue`，通过回调/`Combine` 把进度发回主线程更新 UI。
- **UI 层（AppKit + `NSVisualEffectView`）**：单窗口，四个步骤对应的视图切换（见下），顶部
  步骤指示器，`NSViewController` 按步骤组织。玻璃质感通过 `NSVisualEffectView` 实现，10.15/11
  上退化为纯色圆角背景（无毛玻璃/光晕）。

### 数据流（擦除流程状态机）

```
Idle (等待设备)
  → DetectedUnsupported   (CPID/BDID 不在 Devices.plist / 未 PWND / 找不到对应 iBEC)
  → DetectedReady         (已识别设备 + 已 PWND + iBEC 文件存在) → 用户确认
  → Uploading             (dfu_upload)
  → Booting               (dfu_boot / CUSTOM_BOOT)
  → WaitingRecovery       (等待设备重新以 recovery 模式出现，对应现有 IRecv 连接超时 60s)
  → SendingCommands       (setenv oblit-inprogress 5 / setenv auto-boot true / saveenv)
  → Rebooting             (reboot 指令，允许失败被忽略，与现有逻辑一致)
  → Done  |  Failed(reason)
```

失败分支（USB 断开、上传中断、超时等）统一落到 `Failed(reason)`，UI 按"简洁模式"只显示一行
用户可读的错误信息（如"设备连接中断，请重试"），不暴露堆栈或协议细节。

## UI 设计

引导式四步流程，窗口固定尺寸，顶部步骤指示器（4 个圆点/短横线）贯穿全程：

1. **等待连接** — 提示"请让设备进入 PWND DFU 模式"，中心呼吸动画的图标表示正在监听 USB
2. **确认擦除** — 展示识别到的设备名称、芯片（CPID/BDID）、PWND 状态、匹配到的 iBEC 文件名；
   红色/警示色强调"此操作不可逆"；用户点击确认按钮才会进入下一步
3. **执行中** — 进度指示（不追求精确百分比，分阶段文案：上传中/启动中/等待恢复模式/发送擦除
   指令/重启中），提示"请勿断开设备连接"
4. **完成** — 成功或失败的终态展示；成功时提供"擦除另一台设备"按钮，回到步骤 1

### 视觉风格

macOS 26 液态玻璃（Liquid Glass）+ 渐变光晕（用户选定方案 B）：
- 主容器使用 `NSVisualEffectView`（`.hudWindow` 或自定义 material）营造半透明毛玻璃背景
- 步骤切换时背景有柔和的彩色渐变光晕过渡动效，呼应当前步骤的语义色（等待=中性、确认=警示色、
  执行=进行中色、完成=成功色）
- 控件（按钮、卡片）采用圆角、轻微阴影、浮于玻璃背景之上的层次感

### 版本适配（渐进增强）

| macOS 版本 | 视觉效果 |
|---|---|
| 10.15 – 11 | 纯色圆角背景，无毛玻璃、无光晕动效（`NSVisualEffectView` 材质降级为系统默认或直接用纯色 layer） |
| 12 – 14 | 标准 `NSVisualEffectView` 毛玻璃，简化版光晕过渡 |
| 15+ | 完整液态玻璃质感 + 渐变光晕动效 |

具体判定方式：运行时通过 `ProcessInfo.processInfo.operatingSystemVersion` 分支选择材质和是否
启用动效，而非编译期条件，保证同一份二进制在所有支持版本上都能正确降级。

## 设备支持范围

保持与现有 `usbobliter8` 一致的 11 个设备（A12 `0x8020` / A13 `0x8030`），迁移进
`Devices.plist`：

```
iPhone XS Max (d331), iPhone XR (n841), iPhone XS (d321), iPhone XS Max variant (d331p),
iPad mini 5 (j210) ×2 BDID, iPad Air 3 (j217) ×2 BDID, iPad (8th gen) (ipad11b) ×2 BDID,
iPhone 11 Pro Max (d431), iPhone 11 (n104), iPhone 11 Pro (d421), iPhone SE 2nd gen (d79)
```

不在本次范围内扩展新机型，但 Plist 驱动的架构使后续添加新 `(cpid, bdid)` 条目无需改代码，
只需编辑配置文件并放入对应 iBEC。

## iBEC 文件解析优先级

1. `~/Library/Application Support/EraseA12/boot/iBEC.<codename>.RELEASE.patched`（用户自定义，
   若存在则优先使用）
2. `EraseA12.app/Contents/Resources/boot/iBEC.<codename>.RELEASE.patched`（内嵌默认）

找不到对应文件时，"确认擦除"步骤显示该设备不可用的原因，按钮禁用。

## 错误处理（简洁模式）

- UI 只展示用户可读的一行状态/错误文案（如"未检测到已 PWND 的设备"、"擦除失败：连接中断，
  请重新进入 PWND DFU 模式后重试"）
- 不展示堆栈、协议字节、内部异常类型
- 内部异常仍会被捕获并转换为可枚举的失败原因（用于分支到对应文案），避免 UI 层做字符串猜测

## 分发与安装说明

- 打包为 `.dmg`，ad-hoc 签名（无付费开发者证书）
- README 补充说明：首次打开需要在"系统设置 → 隐私与安全性"允许，或右键点击选择"打开"绕过
  Gatekeeper 未签名警告
- app 依赖的 libirecovery 相关库随 app bundle 一起打包（放入 `Contents/Frameworks/`），不要求
  用户额外 `brew install`

## 本地化

- `en.lproj` / `zh-Hans.lproj` 双语字符串表
- 跟随系统语言自动切换（`NSLocalizedString` 默认行为），无需应用内语言切换开关

## 测试考虑

- `DeviceIdentifier` 的 serial string 解析、`Devices.plist` 查找逻辑：可编写单元测试，用已知
  真实 serial string 样例覆盖已支持/不支持/未 PWND 三种场景
- `IBECResolver` 的路径优先级逻辑：可用临时目录 mock 用户自定义路径 vs bundle 路径
- `ObliterationEngine` 状态机：可通过注入 mock 的 `LibirecoveryBridge`（协议化接口）在无真实
  设备情况下测试状态转移和失败分支
- 真实设备的完整擦除流程无法自动化测试，需人工在真机上验证（明确记录为已知的手动验证项）
