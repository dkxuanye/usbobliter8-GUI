#!/bin/bash
#
# package-dmg.sh - 打包 EraseA12.app 为可视化 DMG
#
# 流程：
#   1. 用 xcodegen 生成工程，clean build Release
#   2. ad-hoc 签名 EraseA12.app
#   3. 调用 Scripts/make-dmg-background.swift 生成 DMG 背景图
#   4. 在 DMG 内容里放置 .background/ 隐藏背景图
#   5. 创建 Applications 文件夹符号链接（标准 DMG 体验）
#   6. 用 osascript 让 Finder 自动配置窗口布局（GUI 环境）
#      无 GUI 环境（如 CI）跳过此步骤，背景图仍可通过 Finder 手动启用
#   7. 写入《打开方式.txt》中英文 README
#   8. 用 hdiutil 生成压缩 UDZO DMG
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
WORKSPACE_DIR="$(dirname "$PROJECT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/Release"
DMG_STAGE_DIR="$PROJECT_DIR/build/dmg-staging"
BACKGROUND_SCRIPT="$SCRIPT_DIR/make-dmg-background.swift"
BACKGROUND_PNG="$SCRIPT_DIR/dmg-background.png"

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PROJECT_DIR/EraseA12/Resources/Info.plist" 2>/dev/null || echo "1.0.0")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PROJECT_DIR/EraseA12/Resources/Info.plist" 2>/dev/null || echo "1")
DMG_NAME="EraseA12-${VERSION}"
DMG_OUTPUT="$WORKSPACE_DIR/${DMG_NAME}.dmg"

echo "=== EraseA12 DMG 打包 ==="
echo "  版本: ${VERSION} (${BUILD})"
echo "  输出: ${DMG_OUTPUT}"

# ---- 1. clean Release 构建 ----
echo ""
echo "[1/6] clean Release 构建..."
cd "$PROJECT_DIR"
if command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate >/dev/null
elif [[ ! -d "$PROJECT_DIR/EraseA12.xcodeproj" ]]; then
    echo "错误：未检测到 xcodegen 且本地不存在 EraseA12.xcodeproj" >&2
    echo "      请先运行: brew install xcodegen && xcodegen generate" >&2
    exit 1
else
    echo "  使用已存在的 EraseA12.xcodeproj（未安装 xcodegen）"
fi
xcodebuild -project EraseA12.xcodeproj -scheme EraseA12 -configuration Release \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    clean build | tail -5

if [[ ! -d "$BUILD_DIR/EraseA12.app" ]]; then
    echo "错误：构建未生成 EraseA12.app" >&2
    exit 1
fi

# ---- 2. ad-hoc 签名 ----
echo ""
echo "[2/6] ad-hoc 签名..."
codesign --force --deep --sign - "$BUILD_DIR/EraseA12.app"
codesign --verify --deep --strict --verbose=2 "$BUILD_DIR/EraseA12.app"

# ---- 3. 生成背景图 ----
echo ""
echo "[3/6] 生成 DMG 背景图..."
if [[ ! -f "$BACKGROUND_PNG" ]]; then
    swift "$BACKGROUND_SCRIPT" "$BACKGROUND_PNG"
fi
ls -la "$BACKGROUND_PNG"

# ---- 4. 准备 DMG 内容 ----
echo ""
echo "[4/6] 准备 DMG 内容..."
rm -rf "$DMG_STAGE_DIR"
mkdir -p "$DMG_STAGE_DIR"
cp -R "$BUILD_DIR/EraseA12.app" "$DMG_STAGE_DIR/"

# 隐藏目录存放背景图
mkdir -p "$DMG_STAGE_DIR/.background"
cp "$BACKGROUND_PNG" "$DMG_STAGE_DIR/.background/dmg-background.png"

# 创建指向本机 /Applications 的符号链接
ln -sf /Applications "$DMG_STAGE_DIR/Applications"

# 写入中英文 README
cat > "$DMG_STAGE_DIR/打开方式.txt" << 'EOF'
首次打开方法：
1. 把 EraseA12.app 拖到右侧 Applications 文件夹
2. 在 Finder → 应用程序 双击 EraseA12
3. 首次启动请右键点击 → 选择"打开"
   或在"系统设置 → 隐私与安全性"中点击"仍要打开"

How to open for the first time:
1. Drag EraseA12.app into the Applications folder on the right
2. In Finder → Applications, double-click EraseA12
3. On first launch, right-click the app → "Open"
   or go to "System Settings → Privacy & Security" → "Open Anyway"
EOF

# ---- 5. 用 Finder 自动配置窗口布局（GUI 环境） ----
echo ""
echo "[5/6] 配置 DMG 窗口布局..."

if [[ "${SKIP_DMG_FINDER_LAYOUT:-0}" == "1" ]]; then
    echo "  跳过（SKIP_DMG_FINDER_LAYOUT=1）"
else
    # 挂载中间态 DMG 让 Finder 自动生成 .DS_Store
    RW_DMG="$PROJECT_DIR/build/${DMG_NAME}-rw.dmg"
    rm -f "$RW_DMG"

    hdiutil create -volname "EraseA12" \
        -srcfolder "$DMG_STAGE_DIR" \
        -ov -format UDRW \
        "$RW_DMG" >/dev/null

    # 用 -plist 输出解析挂载点，避免依赖空格分列
    PLIST_FILE="$PROJECT_DIR/build/.dmg-attach.plist"
    BINARY_PLIST_FILE="$PROJECT_DIR/build/.dmg-attach.binary.plist"
    mkdir -p "$(dirname "$PLIST_FILE")"
    hdiutil attach -nobrowse -readwrite -noverify -plist "$RW_DMG" > "$PLIST_FILE" 2>"$PLIST_FILE.err" || true
    if [[ -s "$PLIST_FILE.err" ]]; then
        echo "  DEBUG hdiutil err: $(cat "$PLIST_FILE.err")"
    fi

    MOUNT_POINT=""
    DEV_NODE=""
    if [[ -s "$PLIST_FILE" ]]; then
        # 把 XML plist 转成 binary1 写入临时文件，避免 binary 里的 NUL 字节截断 shell 变量
        plutil -convert binary1 -o "$BINARY_PLIST_FILE" "$PLIST_FILE" 2>/dev/null || true
        if [[ -s "$BINARY_PLIST_FILE" ]]; then
            for idx in 0 1 2 3 4 5; do
                CANDIDATE_MP=""
                CANDIDATE_DEV=""
                if plutil -extract "system-entities.${idx}.mount-point" raw -o - "$BINARY_PLIST_FILE" >/dev/null 2>&1; then
                    CANDIDATE_MP=$(plutil -extract "system-entities.${idx}.mount-point" raw -o - "$BINARY_PLIST_FILE" 2>/dev/null || true)
                fi
                if plutil -extract "system-entities.${idx}.dev-entry" raw -o - "$BINARY_PLIST_FILE" >/dev/null 2>&1; then
                    CANDIDATE_DEV=$(plutil -extract "system-entities.${idx}.dev-entry" raw -o - "$BINARY_PLIST_FILE" 2>/dev/null || true)
                fi
                if [[ -n "$CANDIDATE_MP" ]] && [[ "$CANDIDATE_MP" == /* ]]; then
                    MOUNT_POINT="$CANDIDATE_MP"
                    DEV_NODE="$CANDIDATE_DEV"
                    break
                fi
            done
        fi
    fi
    rm -f "$PLIST_FILE" "$PLIST_FILE.err" "$BINARY_PLIST_FILE"

    if [[ -n "$MOUNT_POINT" ]] && [[ -d "$MOUNT_POINT" ]]; then
        echo "  挂载点: $MOUNT_POINT"

        # 让 Finder 打开 DMG 窗口并配置背景图 + 视图选项
        osascript <<EOSCRIPT 2>/dev/null || echo "  警告：Finder 自动化失败（可能无 GUI 访问），跳过窗口布局预设"
            tell application "Finder"
                tell disk "EraseA12"
                    open
                    delay 1
                    set current view of container window to icon view
                    set toolbar visible of container window to false
                    set statusbar visible of container window to false
                    set bounds of container window to {200, 120, 820, 560}
                    set theViewOptions to the icon view options of container window
                    set arrangement of theViewOptions to not arranged
                    set icon size of theViewOptions to 96
                    set background picture of theViewOptions to file ".background:dmg-background.png"
                    set position of item "EraseA12.app" of container window to {130, 200}
                    set position of item "Applications" of container window to {410, 200}
                    close
                    open
                    delay 1
                    close
                end tell
            end tell
EOSCRIPT

        sync
        sleep 1
        if [[ -n "$DEV_NODE" ]]; then
            hdiutil detach "$DEV_NODE" >/dev/null 2>&1 || hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
        else
            hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
        fi

        # 把可读写 DMG 转换为压缩 UDZO
        rm -f "$DMG_OUTPUT"
        hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_OUTPUT" >/dev/null
        rm -f "$RW_DMG"

        echo "  已生成压缩 DMG: $DMG_OUTPUT"
    else
        echo "  警告：未能挂载 DMG，跳过窗口布局预设"
        rm -f "$RW_DMG"
        rm -f "$DMG_OUTPUT"
        hdiutil create -volname "EraseA12" \
            -srcfolder "$DMG_STAGE_DIR" \
            -ov -format UDZO \
            -imagekey zlib-level=9 \
            -o "$DMG_OUTPUT" >/dev/null
        echo "  已生成压缩 DMG（无 .DS_Store）: $DMG_OUTPUT"
    fi
fi

# ---- 6. 校验 ----
echo ""
echo "[6/6] 校验 DMG..."
if [[ ! -f "$DMG_OUTPUT" ]]; then
    echo "错误：未生成 DMG" >&2
    exit 1
fi

SIZE=$(du -h "$DMG_OUTPUT" | awk '{print $1}')
SHA=$(shasum -a 256 "$DMG_OUTPUT" | awk '{print $1}')
echo "  文件大小: $SIZE"
echo "  SHA-256:  $SHA"

# 校验 DMG 内确实有 .background/、Applications 和 EraseA12.app
VERIFY_DIR="$PROJECT_DIR/build/dmg-verify"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
hdiutil attach -nobrowse -readonly "$DMG_OUTPUT" >/dev/null
MOUNT_VERIFY=$(hdiutil info | awk '/\/EraseA12$/ {print $3}' | tail -1)
if [[ -d "$MOUNT_VERIFY" ]]; then
    [[ -d "$MOUNT_VERIFY/.background" ]] && echo "  ✓ .background/ 存在" || echo "  ✗ .background/ 缺失"
    [[ -L "$MOUNT_VERIFY/Applications" ]] && echo "  ✓ Applications 符号链接存在" || echo "  ✗ Applications 符号链接缺失"
    [[ -d "$MOUNT_VERIFY/EraseA12.app" ]] && echo "  ✓ EraseA12.app 存在" || echo "  ✗ EraseA12.app 缺失"
    hdiutil detach "$MOUNT_VERIFY" >/dev/null || true
fi
rm -rf "$VERIFY_DIR"

echo ""
echo "完成: $DMG_OUTPUT"