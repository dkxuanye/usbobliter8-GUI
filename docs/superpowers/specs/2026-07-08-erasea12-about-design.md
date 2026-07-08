# EraseA12 关于窗口设计

**日期：** 2026-07-08
**状态：** 已实施并验证

## 目标

为 EraseA12 增加符合 macOS 习惯的“关于 EraseA12”入口和独立窗口，明确展示原项目作者、
原始许可证信息以及原生图形界面的开发者署名。

## 版权依据

- 仓库 `LICENSE` 使用 MIT License，并声明 `Copyright (c) 2026 overcast302`。
- Git 初始提交及原始实现提交的作者均为 `overcast302`。
- 关于窗口不得删除、替换或弱化原作者版权；“玄烨品果”作为原生图形界面开发者单独署名。

## 用户入口

应用创建标准 macOS 应用菜单，在 `EraseA12` 菜单下提供 `关于 EraseA12`。不在四步擦除向导
内增加按钮，避免干扰设备连接和不可逆擦除流程。

## 窗口内容

关于窗口使用简体中文，按以下顺序显示：

1. EraseA12 应用图标和名称。
2. 从 App bundle 读取的版本号与构建号，不硬编码版本。
3. `原项目作者：overcast302`，并提供原项目 GitHub 链接
   `https://github.com/overcast302/usbobliter8`。
4. `由 玄烨品果开发`。
5. 可点击的网站链接 `www.dkxuanye.cn`，目标为 `https://www.dkxuanye.cn`。
6. `Copyright © 2026 overcast302` 与 `MIT License`。

窗口只展示信息和外部链接，不提供修改设置或执行擦除操作的能力。关闭关于窗口不会关闭主窗口。

## 实现边界

- 新建独立的 AppKit 关于窗口控制器，避免把署名布局塞入 `MainWindowController`。
- 由 `AppDelegate` 持有关于窗口控制器并响应菜单动作，防止窗口展示后立即释放。
- 通过 `NSWorkspace` 打开经过代码内固定定义的 HTTPS 链接，不接收用户输入。
- 保持最低部署目标 macOS 10.15，不引入第三方依赖。
- 如需新增 Swift 文件，必须同步 `EraseA12/project.yml`，并重新生成被忽略的 Xcode 工程。

## 测试与验收

- 先添加失败测试，验证关于窗口包含原作者、开发者署名、网站、版权和 MIT License 文案。
- 验证版本信息来自 bundle 数据，并验证菜单包含 `关于 EraseA12`。
- 运行完整 XCTest，确保现有 26 项测试和新增测试全部通过。
- 执行 clean Release 构建，检查严格签名、universal 架构、字符串表和 `git diff --check`。
- 不连接设备，不执行任何真机擦除操作。
