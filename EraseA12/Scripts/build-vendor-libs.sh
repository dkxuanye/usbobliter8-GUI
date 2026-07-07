#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="$PROJECT_DIR/Vendor/libirecovery"
BUILD_DIR="$PROJECT_DIR/.vendor-build"
PREFIX_X86="$BUILD_DIR/prefix-x86_64"
PREFIX_ARM="$BUILD_DIR/prefix-arm64"

DEPLOY_TARGET="10.15"
NPROC=$(sysctl -n hw.ncpu)

# Source tarballs — download if not cached
LIBPLIST_VER="2.7.0"
LIBUSB_VER="1.0.30"
GLUE_VER="1.3.2"
IRECV_VER="1.3.1"

LIBPLIST_URL="https://github.com/libimobiledevice/libplist/releases/download/${LIBPLIST_VER}/libplist-${LIBPLIST_VER}.tar.bz2"
LIBUSB_URL="https://github.com/libusb/libusb/releases/download/v${LIBUSB_VER}/libusb-${LIBUSB_VER}.tar.bz2"
GLUE_URL="https://github.com/libimobiledevice/libimobiledevice-glue/releases/download/${GLUE_VER}/libimobiledevice-glue-${GLUE_VER}.tar.bz2"
IRECV_URL="https://github.com/libimobiledevice/libirecovery/releases/download/${IRECV_VER}/libirecovery-${IRECV_VER}.tar.bz2"

echo "=== EraseA12 Vendor Lib Builder ==="
echo "Building universal static libs with MACOSX_DEPLOYMENT_TARGET=${DEPLOY_TARGET}"
echo ""

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$BUILD_DIR/tarballs" "$PREFIX_X86" "$PREFIX_ARM"

download() {
    local url="$1"
    local name="$(basename "$url")"
    local dest="$BUILD_DIR/tarballs/$name"
    if [ ! -f "$dest" ]; then
        echo "Downloading $name..."
        curl -sL "$url" -o "$dest"
    fi
    echo "Extracting $name..."
    tar xf "$dest" -C "$BUILD_DIR"
}

download "$LIBPLIST_URL"
download "$LIBUSB_URL"
download "$GLUE_URL"
download "$IRECV_URL"

build_lib() {
    local src_dir="$1"
    local prefix="$2"
    local arch="$3"
    shift 3
    # Remaining args are extra configure flags
    local extra_args=("$@")

    echo "--- Building $(basename "$src_dir") for $arch ---"

    local target_flag=""
    if [ "$arch" = "x86_64" ]; then
        target_flag="-target x86_64-apple-macos${DEPLOY_TARGET}"
    else
        target_flag="-target arm64-apple-macos${DEPLOY_TARGET}"
    fi

    local common_flags="$target_flag -mmacosx-version-min=${DEPLOY_TARGET} -O2"

    cd "$src_dir"
    make clean 2>/dev/null || true

    export PKG_CONFIG_PATH="$prefix/lib/pkgconfig"

    CFLAGS="$common_flags" \
    CXXFLAGS="$common_flags" \
    LDFLAGS="$common_flags" \
    ./configure \
        --host="$arch-apple-darwin" \
        --prefix="$prefix" \
        --enable-static \
        --disable-shared \
        "${extra_args[@]}"

    make -j"$NPROC"
    make install

    unset PKG_CONFIG_PATH
}

# Build order: libplist → libusb → libimobiledevice-glue → libirecovery
# Each depends on the previous ones

for ARCH in x86_64 arm64; do
    echo ""
    echo "========== Building for $ARCH =========="
    PREFIX="$BUILD_DIR/prefix-$ARCH"

    # libplist (no deps)
    build_lib "$BUILD_DIR/libplist-${LIBPLIST_VER}" "$PREFIX" "$ARCH" \
        --without-cython

    # libusb (no deps beyond system)
    build_lib "$BUILD_DIR/libusb-${LIBUSB_VER}" "$PREFIX" "$ARCH" \
        --disable-udev

    # libimobiledevice-glue (depends on libplist)
    build_lib "$BUILD_DIR/libimobiledevice-glue-${GLUE_VER}" "$PREFIX" "$ARCH" \
        --without-cython

    # libirecovery (depends on libplist, libusb, libimobiledevice-glue)
    build_lib "$BUILD_DIR/libirecovery-${IRECV_VER}" "$PREFIX" "$ARCH" \
        --without-cython
done

# Create universal static libs with lipo
echo ""
echo "=== Creating universal static libraries ==="
mkdir -p "$VENDOR_DIR/lib"

for LIB in libplist-2.0.a libplist++-2.0.a libusb-1.0.a libimobiledevice-glue-1.0.a libirecovery-1.0.a; do
    echo "Lipo: $LIB"
    lipo -create \
        "$PREFIX_X86/lib/$LIB" \
        "$PREFIX_ARM/lib/$LIB" \
        -output "$VENDOR_DIR/lib/$LIB"
done

# Copy header
cp /usr/local/include/libirecovery.h "$VENDOR_DIR/include/libirecovery.h"

# Verify
echo ""
echo "=== Verification ==="
for LIB in "$VENDOR_DIR/lib"/*.a; do
    echo "$(basename "$LIB"): $(lipo -info "$LIB")"
done

echo ""
echo "Done! Vendor libs built to $VENDOR_DIR/lib/"
echo "These .a files should be committed to the repository."
