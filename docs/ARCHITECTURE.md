# ARCHITECTURE.md - 项目架构

## 项目用途

仓库保留原始 Python/PyQt5 `usbobliter8`，同时提供原生 macOS 应用 EraseA12。两者都要求设备
事先由外部 `usbliter8` 工具进入 PWND DFU；本项目不实现 exploit，只负责识别设备、上传
patched iBEC、设置擦除相关 NVRAM 并重启。

## 技术栈

- 语言：Swift 5、C 桥接；旧版工具为 Python。
- UI：AppKit，窗口背景使用 `NSVisualEffectView`。
- USB：IOKit 设备通知和 libirecovery。
- 构建：Xcode、xcodebuild、xcodegen；最低部署目标 macOS 10.15。
- 配置：`Devices.plist`、`project.yml`、`.lproj/Localizable.strings`。
- 测试：XCTest，通过协议注入 mock libirecovery。
- 数据库：无。

## 主要目录说明

- `EraseA12/EraseA12/App/`: 应用入口、AppDelegate 和本地化入口。
- `EraseA12/EraseA12/Bridge/`: libirecovery C/Swift 互操作层。
- `EraseA12/EraseA12/Core/`: 设备识别、iBEC 解析、USB 监听和擦除状态机。
- `EraseA12/EraseA12/UI/`: 四步 AppKit 界面与窗口编排。
- `EraseA12/EraseA12/Resources/`: 设备表、11 份 iBEC、字符串表和 Info.plist。
- `EraseA12/EraseA12Tests/`: 识别、资源解析、状态机和 UI 回归测试。
- `EraseA12/Vendor/libirecovery/`: universal 静态库和头文件。
- `EraseA12/Scripts/`: vendor 库构建与 DMG 打包脚本。
- `boot/`、`main.py`: 原始 Python 版本及其 iBEC 资源。
- `.github/workflows/`: 当前只覆盖 Python/PyInstaller 构建。

## 核心模块说明

- `USBDeviceMonitor`: 监听 Apple VID `0x05AC`、DFU PID `0x1227` 的插拔事件，200ms 防抖。
- `DeviceIdentifier`: 解析 USB serial string，按 `(CPID, BDID)` 查询 `Devices.plist`。
- `IBECResolver`: 用户覆盖目录优先，其次 app bundle；兼容 `Resources/boot/` 和扁平化资源根目录。
- `LibirecoveryBridge`: 把 libirecovery C API 和错误码封装成 Swift 方法及错误。
- `ObliterationEngine`: 在后台串行队列执行不可逆擦除流程，并把状态回调到主线程。
- `MainWindowController`: 管理 USB 监听、设备确认、四个步骤控制器切换和右上角关于按钮。
- `L10n`: 固定加载 `zh-Hans.lproj`，确保应用不随系统语言切回英文。
- `AppDelegate`: 创建标准应用菜单，持有主窗口和关于窗口控制器。
- `AboutWindowController`: 展示 bundle 版本、原项目版权、MIT License、GUI 开发者署名和固定 HTTPS 链接。

## 启动方式

本地已有产物时可直接打开：

```bash
open EraseA12.app
```

应用使用 ad-hoc 签名；其他 Mac 首次打开可能需要右键选择“打开”或在隐私与安全性中允许。

## 构建方式

标准方式需要 xcodegen：

```bash
cd EraseA12
brew install xcodegen
xcodegen generate -s project.yml -o EraseA12.xcodeproj
xcodebuild -project EraseA12.xcodeproj -scheme EraseA12 -configuration Release build
```

输出到仓库根目录的已验证命令：

```bash
xcodebuild build \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$PWD"
```

`EraseA12.xcodeproj` 是本机生成文件并被忽略，不是长期配置源。

## 测试方式

```bash
xcodebuild test \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Debug \
  -destination 'platform=macOS'
```

测试覆盖设备 serial 解析、iBEC 路径优先级、擦除状态机成功/失败分支、中文 UI 布局、关于窗口
版权内容、链接和应用菜单入口。

## 配置文件说明

- `EraseA12/project.yml`: xcodegen 工程标准来源，定义 target、资源、签名和链接参数。
- `EraseA12/EraseA12/Resources/Devices.plist`: 支持设备到 iBEC codename 的映射。
- `EraseA12/EraseA12/Resources/Info.plist`: bundle 元数据和最低系统版本相关配置。
- `EraseA12/EraseA12/EraseA12.entitlements`: USB 设备访问 entitlement；应用沙盒关闭。
- `EraseA12/EraseA12/Resources/zh-Hans.lproj/Localizable.strings`: 实际用户界面文案。
- `EraseA12/EraseA12/Resources/en.lproj/Localizable.strings`: 英文参考资源，目前不会主动显示。

## 数据流 / 主要调用链

```text
IOKit 检测 DFU 设备
  -> USBDeviceMonitor 读取 USB Serial Number
  -> DeviceIdentifier 解析 CPID/BDID/ECID/PWND
  -> IBECResolver 匹配 patched iBEC
  -> MainWindowController 展示确认页
  -> 用户确认
  -> ObliterationEngine + LibirecoveryBridge
     -> 连接 DFU
     -> 上传 iBEC
     -> reset counters / finish transfer
     -> 等待 Recovery 模式重连（最长 60 秒）
     -> setenv oblit-inprogress 5
     -> setenv auto-boot true
     -> saveenv
     -> reboot
  -> 完成或失败页
```

应用启动时，`AppDelegate` 同时创建 `EraseA12` 菜单，并向 `MainWindowController` 注入
`onShowAbout` 回调。用户可选择菜单或点击主窗口右上角圆形 `!` 打开同一个独立信息窗口。
关于窗口不访问设备，也不调用 `ObliterationEngine`。

## 注意事项

- 擦除不可逆；单元测试使用 mock，不应对真实个人设备运行自动化擦除。
- 用户自定义 iBEC 路径为
  `~/Library/Application Support/EraseA12/boot/iBEC.<codename>.RELEASE.patched`，优先级高于内嵌资源。
- 当前二进制虽为 `x86_64 + arm64`，但仍动态引用 `/usr/local/opt/openssl@3`，尚未实现真正自包含分发。
- vendor 的 libirecovery、libusb、libplist 和 libimobiledevice-glue 是 universal 静态库。
- ad-hoc 签名和关闭 hardened runtime 适合当前私人测试，不等同于可公开分发的签名、公证方案。
