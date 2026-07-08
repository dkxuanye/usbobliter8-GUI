# AGENTS.md - Codex 项目指引

## 必读文件

每次开始任务前必须按顺序读取：

1. `HANDOFF.md` - 当前状态和交接信息
2. `DEV_LOG.md` - 最近修改和决策
3. `TODO.md` - 待办事项
4. `docs/ARCHITECTURE.md` - 项目架构
5. `BUG_HANDOFF.md`（如果存在）- Bug 交接信息

## 核心原则

- 不要只相信聊天历史，项目文件、`git diff`、`git log` 和验证输出才是事实来源。
- 修改代码前先总结当前理解、风险和计划，不要未经确认进行大规模重构。
- 与用户默认使用中文沟通；EraseA12 的用户可见界面固定使用简体中文。
- 不要提交 `EraseA12.app/`、`build/`、截图、日志、`.DS_Store` 等生成物。
- 不要回退不属于当前任务的已有改动；工作区可能包含用户保留的实验结果。
- 擦除流程具有破坏性。没有明确授权和受控测试设备时，不执行真机擦除验证。

## 任务执行要求

- 每次任务结束必须更新 `HANDOFF.md`、`DEV_LOG.md` 和 `TODO.md`。
- 修改后运行相关测试；涉及发布时还要执行 Release 构建、签名校验和依赖检查。
- 无法运行测试时必须说明原因，不得把未验证内容写成已确认事实。
- 同一个 Bug 连续修复 2 至 3 次仍失败时，创建或更新 `BUG_HANDOFF.md`，并建议开新会话。

## EraseA12 验证基线

从仓库根目录执行：

```bash
xcodebuild test \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Debug \
  -destination 'platform=macOS'

xcodebuild build \
  -project EraseA12/EraseA12.xcodeproj \
  -scheme EraseA12 \
  -configuration Release \
  CONFIGURATION_BUILD_DIR="$PWD"
```

随后至少检查：

```bash
codesign --verify --deep --strict --verbose=2 EraseA12.app
file EraseA12.app/Contents/MacOS/EraseA12
otool -L EraseA12.app/Contents/MacOS/EraseA12
plutil -lint EraseA12/EraseA12/Resources/*/Localizable.strings
git diff --check
```

`EraseA12.xcodeproj` 被忽略，标准来源是 `EraseA12/project.yml`。新增源文件或测试后，应使用
`xcodegen generate -s EraseA12/project.yml -o EraseA12/EraseA12.xcodeproj` 重新生成项目。

## 会话管理

出现以下情况时，先完成交接再开新会话：

- 当前会话过长或已经发生上下文压缩
- 模型开始重复、混乱或遗忘已验证结论
- 修改文件过多，下一步需要切换到真机、打包或发布阶段
