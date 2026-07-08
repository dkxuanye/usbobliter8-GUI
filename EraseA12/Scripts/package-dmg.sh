#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/Release"
DMG_NAME="EraseA12-1.0.0"
DMG_DIR="$PROJECT_DIR/build/dmg"

echo "=== EraseA12 DMG Packaging ==="

# Build release
echo "Building Release..."
cd "$PROJECT_DIR"
xcodegen generate
xcodebuild -project EraseA12.xcodeproj -scheme EraseA12 -configuration Release \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    clean build

# Ad-hoc sign
echo "Ad-hoc signing..."
codesign --force --deep --sign - "$BUILD_DIR/EraseA12.app"

# Create DMG structure
echo "Creating DMG..."
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"
cp -R "$BUILD_DIR/EraseA12.app" "$DMG_DIR/"

# Create a README with Gatekeeper instructions
cat > "$DMG_DIR/README-打开方式.txt" << 'EOF'
首次打开方法：
1. 右键点击 EraseA12.app → 选择"打开"
2. 或在"系统设置 → 隐私与安全性"中点击"仍要打开"

How to open for the first time:
1. Right-click EraseA12.app → Select "Open"
2. Or go to "System Settings → Privacy & Security" and click "Open Anyway"
EOF

# Create DMG
hdiutil create -volname "EraseA12" \
    -srcfolder "$DMG_DIR" \
    -ov -format UDZO \
    "${DMG_NAME}.dmg"

echo "Done: ${DMG_NAME}.dmg"
