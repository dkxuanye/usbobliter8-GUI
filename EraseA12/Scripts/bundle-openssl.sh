#!/bin/bash
#
# bundle-openssl.sh - 把 OpenSSL dylib 嵌入 EraseA12.app/Contents/Frameworks/
#
# 调用前需先跑 Scripts/build-openssl.sh 编译出 universal dylib。
#
# 流程：
# 1. 拷贝 libssl.3.dylib / libcrypto.3.dylib 到 .app/Contents/Frameworks/
# 2. 改 dylib 自己的 install_name 为 @rpath 形式
# 3. 改 EraseA12 二进制对 libssl/libcrypto 的引用路径
# 4. 改 libssl 内部对 libcrypto 的引用
# 5. 重新签名（先 dylib，再 app）
#
# 用法：./Scripts/bundle-openssl.sh [path/to/EraseA12.app]
#   默认路径：build/Release/EraseA12.app
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_OPENSSL_DIR="$PROJECT_DIR/Vendor/openssl"

APP_PATH="${1:-$PROJECT_DIR/build/Release/EraseA12.app}"
FRAMEWORKS_DIR="$APP_PATH/Contents/Frameworks"
EXECUTABLE="$APP_PATH/Contents/MacOS/EraseA12"

echo "=== EraseA12 OpenSSL Bundling ==="
echo "App:      $APP_PATH"
echo "Vendor:   $VENDOR_OPENSSL_DIR"
echo ""

# ---- 0. 前置检查 ----
for LIB in libssl.3.dylib libcrypto.3.dylib; do
    if [ ! -f "$VENDOR_OPENSSL_DIR/lib/$LIB" ]; then
        echo "错误：$VENDOR_OPENSSL_DIR/lib/$LIB 不存在" >&2
        echo "请先跑：./Scripts/build-openssl.sh" >&2
        exit 1
    fi
done

if [ ! -d "$APP_PATH" ] || [ ! -f "$EXECUTABLE" ]; then
    echo "错误：$APP_PATH 不是有效的 app bundle" >&2
    exit 1
fi

# ---- 1. 拷贝 dylib 到 .app/Contents/Frameworks/ ----
echo "[1/5] 拷贝 dylib 到 Frameworks/..."
mkdir -p "$FRAMEWORKS_DIR"
cp "$VENDOR_OPENSSL_DIR/lib/libssl.3.dylib" "$FRAMEWORKS_DIR/"
cp "$VENDOR_OPENSSL_DIR/lib/libcrypto.3.dylib" "$FRAMEWORKS_DIR/"
chmod 755 "$FRAMEWORKS_DIR/libssl.3.dylib" "$FRAMEWORKS_DIR/libcrypto.3.dylib"
# 移除 quarantine 属性（如果之前有）
xattr -dr com.apple.quarantine "$FRAMEWORKS_DIR/libssl.3.dylib" 2>/dev/null || true
xattr -dr com.apple.quarantine "$FRAMEWORKS_DIR/libcrypto.3.dylib" 2>/dev/null || true

# ---- 2. 改 dylib 自己的 install_name（用 @rpath） ----
echo "[2/5] 改 dylib install_name..."
install_name_tool -id "@rpath/libssl.3.dylib" "$FRAMEWORKS_DIR/libssl.3.dylib"
install_name_tool -id "@rpath/libcrypto.3.dylib" "$FRAMEWORKS_DIR/libcrypto.3.dylib"

# ---- 3. 改 libssl 对 libcrypto 的内部引用 ----
echo "[3/5] 修复 libssl 内部对 libcrypto 的引用..."
# 查看 libssl 当前对 libcrypto 的引用路径
OLD_CRYPTO_REF=$(otool -L "$FRAMEWORKS_DIR/libssl.3.dylib" | \
    awk '/libcrypto/ {print $1; exit}' || true)
if [ -n "$OLD_CRYPTO_REF" ]; then
    install_name_tool -change \
        "$OLD_CRYPTO_REF" \
        "@rpath/libcrypto.3.dylib" \
        "$FRAMEWORKS_DIR/libssl.3.dylib"
    echo "  $OLD_CRYPTO_REF -> @rpath/libcrypto.3.dylib"
fi

# ---- 4. 改 EraseA12 二进制对 libssl/libcrypto 的引用 ----
echo "[4/5] 改 EraseA12 二进制的依赖路径..."
# 主可执行
OLD_SSL_REF=$(otool -L "$EXECUTABLE" | awk '/libssl/ {print $1; exit}' || true)
OLD_CRYPTO_REF=$(otool -L "$EXECUTABLE" | awk '/libcrypto/ {print $1; exit}' || true)

# 添加 @rpath 到可执行文件的 LC_RPATH（如果还没）
# macOS 默认搜索顺序：@executable_path/../Frameworks
# 我们用相对路径 @loader_path/../Frameworks 更稳健（在 dylib 里也能用）
EXE_RPATH="@executable_path/../Frameworks"
if ! otool -l "$EXECUTABLE" | grep -q "path $EXE_RPATH "; then
    install_name_tool -add_rpath "$EXE_RPATH" "$EXECUTABLE"
fi

if [ -n "$OLD_SSL_REF" ]; then
    install_name_tool -change \
        "$OLD_SSL_REF" \
        "@rpath/libssl.3.dylib" \
        "$EXECUTABLE"
    echo "  $OLD_SSL_REF -> @rpath/libssl.3.dylib"
fi

if [ -n "$OLD_CRYPTO_REF" ]; then
    install_name_tool -change \
        "$OLD_CRYPTO_REF" \
        "@rpath/libcrypto.3.dylib" \
        "$EXECUTABLE"
    echo "  $OLD_CRYPTO_REF -> @rpath/libcrypto.3.dylib"
fi

# ---- 5. 重新签名 ----
echo "[5/5] 重新签名..."
# 先签 dylib（ad-hoc 即可，macOS 允许）
codesign --force --sign - "$FRAMEWORKS_DIR/libcrypto.3.dylib"
codesign --force --sign - "$FRAMEWORKS_DIR/libssl.3.dylib"
# 再签整个 app
codesign --force --deep --sign - "$APP_PATH"

# ---- 验证 ----
echo ""
echo "=== 验证 ==="
echo "App Frameworks/:"
ls -la "$FRAMEWORKS_DIR"

echo ""
echo "EraseA12 二进制动态依赖（应该不再有 /usr/local/opt）:"
otool -L "$EXECUTABLE" | grep -E "ssl|crypto" || echo "  ✓ 没有外部 openssl 引用"

echo ""
echo "严格签名验证:"
codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1

echo ""
echo "完成: $APP_PATH 现在自包含 OpenSSL，可分发给没有 Homebrew OpenSSL 的 Mac"