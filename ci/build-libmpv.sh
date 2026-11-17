#!/usr/bin/env bash
set -e

deps="$PWD/deps"

case "$1" in
android)
    toolchain="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin"
    cc="$toolchain/aarch64-linux-android21-clang"
    export PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig"
    ffmpeg_args=(--enable-cross-compile --target-os=android --arch=aarch64
                 --cross-prefix="$toolchain/llvm-" --cc="$cc" --enable-{jni,mediacodec})
    mpv_args=(--cross-file cross.ini -Dlibass:require-system-font-provider=false)
    cat > cross.ini <<EOF
[binaries]
c = '$cc'
cpp = '$cc++'
ar = '$toolchain/llvm-ar'
pkg-config = 'pkg-config'

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
    export PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig"
    clang="'-target', 'arm64-apple-ios13.0', '-isysroot', '$MACOS_SDK'"
    ffmpeg_args=(--enable-cross-compile --target-os=darwin --arch=arm64
                 --cc="clang -target arm64-apple-ios13.0 -isysroot $MACOS_SDK" --enable-videotoolbox)
    mpv_args=(--cross-file cross.ini -D{avfoundation,coreaudio,videotoolbox-gl}=disabled)
    cat > cross.ini <<EOF
[binaries]
c = ['clang', $clang]
cpp = ['clang++', $clang]
objc = ['clang', $clang]
pkg-config = 'pkg-config'

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
linux)
    export PKG_CONFIG_PATH="$deps/lib/pkgconfig"
    ffmpeg_args=()
    mpv_args=(-Degl=disabled -Dlibass:require-system-font-provider=false)
    ;;
esac

git clone --depth 1 --branch release/9.1 https://github.com/FFmpeg/FFmpeg.git ffmpeg
pushd ffmpeg
./configure --prefix="$deps" "${ffmpeg_args[@]}" \
            --enable-{pic,zlib} --disable-{autodetect,avdevice,debug,doc,programs}
make -j"$(getconf _NPROCESSORS_ONLN)" install
popd

mkdir -p subprojects
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

meson setup build "${mpv_args[@]}" \
  --buildtype=release \
  --default-library=static \
  --prefer-static \
  --prefix="$PWD/artifact" \
  -D:default_library=shared \
  -Dcplayer=false
meson compile -C build
meson install -C build --skip-subprojects
