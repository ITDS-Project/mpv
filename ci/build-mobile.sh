#!/usr/bin/env bash
set -e

case "$1" in
android)
    toolchain="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
    args=(-Dffmpeg:mediandk=enabled -Dlibass:require-system-font-provider=false)
    cat > cross.ini <<EOF
[binaries]
c = '$toolchain/aarch64-linux-android21-clang'
cpp = '$toolchain/aarch64-linux-android21-clang++'
ar = '$toolchain/llvm-ar'

[built-in options]
cpp_link_args = ['-static-libstdc++']

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF
    ;;
ios)
    export MACOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
    export MACOS_SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"
    clang="'-target', 'arm64-apple-ios13.0', '-isysroot', '$MACOS_SDK'"
    args=(-D{avfoundation,coreaudio,videotoolbox-gl}=disabled)
    cat > cross.ini <<EOF
[binaries]
c = ['clang', $clang]
cpp = ['clang++', $clang]
objc = ['clang', $clang]

[properties]
needs_exe_wrapper = true

[host_machine]
system = 'darwin'
subsystem = 'ios'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF
    ;;
esac

mkdir -p subprojects
cat > subprojects/ffmpeg.wrap <<EOF
[wrap-git]
url = https://gitlab.freedesktop.org/gstreamer/meson-ports/ffmpeg.git
revision = meson-9.0
depth = 1

[provide]
dependency_names = libavcodec, libavfilter, libavformat, libavutil, libswresample, libswscale
EOF
cat > subprojects/libass.wrap <<EOF
[wrap-git]
url = https://github.com/libass/libass
revision = master
depth = 1
EOF
cat > subprojects/libplacebo.wrap <<EOF
[wrap-git]
url = https://code.videolan.org/videolan/libplacebo.git
revision = master
depth = 1
clone-recursive = true
EOF
meson wrap install freetype2
meson wrap install fribidi
meson wrap install harfbuzz

meson setup build "${args[@]}" \
  --cross-file cross.ini \
  --buildtype=release \
  --default-library=static \
  --prefix="$PWD/artifact" \
  -D:default_library=shared \
  -Dcplayer=false \
  -Dffmpeg:{programs,tests}=disabled
meson compile -C build
meson install -C build --skip-subprojects
