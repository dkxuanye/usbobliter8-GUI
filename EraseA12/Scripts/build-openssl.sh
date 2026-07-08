#!/bin/bash
#
# build-openssl.sh - 编译 universal OpenSSL dylib（x86_64 + arm64）
#
# 用于把 libssl/libcrypto 嵌入到 EraseA12.app/Contents/Frameworks/，
# 消除对 /usr/local/opt/openssl@3 的运行时依赖，做到开箱即用。
#
# 产物：EraseA12/Vendor/openssl/lib/libssl.3.dylib
#       EraseA12/Vendor/openssl/lib/libcrypto.3.dylib
#       均为 Mach-O universal binary（x86_64 + arm64）
#
# 用法：./Scripts/build-openssl.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_DIR/Vendor/openssl"
BUILD_DIR="$PROJECT_DIR/.vendor-build/openssl"
PREFIX_X86="$BUILD_DIR/prefix-x86_64"
PREFIX_ARM="$BUILD_DIR/prefix-arm64"

OPENSSL_VER="3.6.2"
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VER}.tar.gz"

DEPLOY_TARGET="10.15"
NPROC=$(sysctl -n hw.ncpu)

echo "=== EraseA12 OpenSSL Universal Builder ==="
echo "Building OpenSSL ${OPENSSL_VER} universal dylibs (MACOSX_DEPLOYMENT_TARGET=${DEPLOY_TARGET})"
echo ""

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$BUILD_DIR/tarballs" \
         "$VENDOR_DIR/include" "$VENDOR_DIR/lib" \
         "$PREFIX_X86" "$PREFIX_ARM"

TARBALL="$BUILD_DIR/tarballs/openssl-${OPENSSL_VER}.tar.gz"
if [ ! -f "$TARBALL" ]; then
    echo "Downloading openssl-${OPENSSL_VER}.tar.gz..."
    curl -sL "$OPENSSL_URL" -o "$TARBALL"
fi

SRC_DIR="$BUILD_DIR/openssl-${OPENSSL_VER}"
if [ ! -d "$SRC_DIR" ]; then
    echo "Extracting..."
    tar xf "$TARBALL" -C "$BUILD_DIR"
fi

# OpenSSL 3.x 用 perl Configure
build_openssl() {
    local arch="$1"
    local prefix="$2"

    echo ""
    echo "========== Building OpenSSL for $arch =========="

    local target=""
    if [ "$arch" = "x86_64" ]; then
        target="darwin64-x86_64-cc"
    else
        target="darwin64-arm64-cc"
    fi

    cd "$SRC_DIR"
    make clean 2>/dev/null || true

    # 注意：OpenSSL 3 的 Configure 不接受 MACOSX_DEPLOYMENT_TARGET 通过环境变量，
    # 必须用 -mmacosx-version-min 编译选项传入
    local cflags="-mmacosx-version-min=${DEPLOY_TARGET} -O2"
    local cxxflags="-mmacosx-version-min=${DEPLOY_TARGET} -O2"

    if [ "$arch" = "x86_64" ]; then
        CFLAGS="$cflags" \
        CXXFLAGS="$cxxflags" \
        perl ./Configure "$target" \
            --prefix="$prefix" \
            --openssldir="$prefix" \
            no-shared \
            no-tests \
            no-ui-console \
            no-apps \
            no-dso \
            no-ssl3 \
            no-zlib
    else
        CFLAGS="$cflags" \
        CXXFLAGS="$cxxflags" \
        perl ./Configure "$target" \
            --prefix="$prefix" \
            --openssldir="$prefix" \
            no-shared \
            no-tests \
            no-ui-console \
            no-apps \
            no-dso \
            no-ssl3 \
            no-zlib
    fi

    make -j"$NPROC"
    make install_sw

    unset CFLAGS CXXFLAGS
}

for ARCH in x86_64 arm64; do
    PREFIX="$BUILD_DIR/prefix-$ARCH"
    build_openssl "$ARCH" "$PREFIX"
done

# OpenSSL 静态库用 lipo 合成 universal
echo ""
echo "=== Creating universal static libraries ==="
mkdir -p "$VENDOR_DIR/lib"

for LIB in libssl.a libcrypto.a; do
    if [ ! -f "$PREFIX_X86/lib/$LIB" ] || [ ! -f "$PREFIX_ARM/lib/$LIB" ]; then
        echo "WARN: missing $LIB in one of the arch builds, skipping" >&2
        continue
    fi
    echo "Lipo: $LIB"
    lipo -create \
        "$PREFIX_X86/lib/$LIB" \
        "$PREFIX_ARM/lib/$LIB" \
        -output "$VENDOR_DIR/lib/$LIB"
done

# OpenSSL 动态库：用 dylib bundling 时需要 universal dylib，
# 因此这里用 libtool/lipo 合成 universal .3.dylib
# 但因为我们用 no-shared 编译，prefix 里没有 .dylib。
# 改为：临时用 shared=1 重编一次，只拿 dylib
# （更简单：在 build_openssl 里加一次 shared 重编）

# 重新编 shared 版本只为拿 dylib
build_openssl_shared() {
    local arch="$1"
    local prefix="$2"

    echo ""
    echo "========== Building OpenSSL shared libs for $arch =========="

    cd "$SRC_DIR"
    make clean 2>/dev/null || true

    local target=""
    if [ "$arch" = "x86_64" ]; then
        target="darwin64-x86_64-cc"
    else
        target="darwin64-arm64-cc"
    fi

    local cflags="-mmacosx-version-min=${DEPLOY_TARGET} -O2"
    CFLAGS="$cflags" CXXFLAGS="$cflags" \
    perl ./Configure "$target" \
        --prefix="$prefix" \
        --openssldir="$prefix" \
        shared \
        no-tests \
        no-ui-console \
        no-apps \
        no-ssl3 \
        no-zlib

    make -j"$NPROC"
    make install_sw
}

for ARCH in x86_64 arm64; do
    PREFIX="$BUILD_DIR/prefix-$ARCH"
    build_openssl_shared "$ARCH" "$PREFIX"
done

# 用 lipo 合成 universal dylib
echo ""
echo "=== Creating universal shared libraries ==="

for LIB in libssl.3.dylib libcrypto.3.dylib; do
    if [ ! -f "$PREFIX_X86/lib/$LIB" ] || [ ! -f "$PREFIX_ARM/lib/$LIB" ]; then
        echo "WARN: missing $LIB in one of the arch builds, skipping" >&2
        continue
    fi
    echo "Lipo: $LIB"
    lipo -create \
        "$PREFIX_X86/lib/$LIB" \
        "$PREFIX_ARM/lib/$LIB" \
        -output "$VENDOR_DIR/lib/$LIB"
done

# 复制 header 和 pkgconfig
cp -R "$PREFIX_X86/include/openssl" "$VENDOR_DIR/include/" 2>/dev/null || true
[ -d "$VENDOR_DIR/include/openssl" ] || echo "WARN: openssl headers not found"

# 验证
echo ""
echo "=== Verification ==="
for LIB in "$VENDOR_DIR/lib"/*.dylib; do
    [ -f "$LIB" ] || continue
    echo "$(basename "$LIB"): $(lipo -info "$LIB" | head -1)"
done

echo ""
echo "Done! Vendor OpenSSL libs built to $VENDOR_DIR/lib/"
echo "Note: .a files can be used for static linking; .dylib files for dylib bundling."