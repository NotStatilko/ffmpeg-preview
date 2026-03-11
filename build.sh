#!/usr/bin/env bash
set -euxo pipefail

# Read FFmpeg tag
TAG=$(cat ffmpeg_tag.txt)
echo "Building FFmpeg tag: $TAG"

# Clone FFmpeg
echo "Cloning FFmpeg"
git clone \
  --depth 1 \
  --branch "$TAG" \
  --single-branch \
  https://github.com/FFmpeg/FFmpeg.git

cd FFmpeg

# Detect platform
OS="$(uname -s)"
ARCH="$(uname -m)"
PREFIX="$(pwd)/build"

# -----------------------------
# Common configure flags
# -----------------------------
COMMON_FLAGS=(
  --disable-everything
  --enable-small
  --enable-ffmpeg
  --enable-ffprobe
  --enable-protocol=file,pipe

  --enable-decoder=h264,hevc,mpeg4,vp8,vp9,av1,mjpeg,gif,theora,aac,mp3,pcm_s16le,opus,vorbis,flac,alac,ac3,eac3,aiff,wma,png,jpeg,heif,bmp,tiff,webp
  --enable-parser=h264,hevc,mpeg4,aac,mp3,opus,vorbis
  --enable-demuxer=mov,mp4,mkv,avi,webm,flv,mp3,wav,flac,ogg,m4a,ac3,aiff,caf,wma,png,jpeg,heif,gif,bmp,tiff,image2

  --enable-encoder=mjpeg
  --enable-muxer=mjpeg
  --enable-filter=scale

  --disable-network
  --disable-doc
  --disable-debug
  --disable-ffplay

  --enable-static
  --disable-shared
)

EXTRA_FLAGS=()

# -----------------------------
# Platform-specific flags
# -----------------------------
if [[ "$OS" == "Darwin" ]]; then
  echo "Configuring for macOS"

  export CC=clang
  export CXX=clang++

  SDKROOT=$(xcrun --show-sdk-path)

  EXTRA_FLAGS+=(
    --extra-cflags="-isysroot $SDKROOT -arch $ARCH"
    --extra-ldflags="-isysroot $SDKROOT -arch $ARCH"
  )

elif [[ "$OS" == MINGW* || "$OS" == MSYS* ]]; then
  echo "Configuring for Windows"

  EXTRA_FLAGS+=(
    --extra-cflags="-static"
    --extra-ldflags="-static"
  )

else
  echo "Configuring for Linux"

  EXTRA_FLAGS+=(
    --extra-cflags="-static"
    --extra-ldflags="-static"
  )
fi

# -----------------------------
# Configure
# -----------------------------
echo "Running configure"
./configure \
  "${COMMON_FLAGS[@]}" \
  "${EXTRA_FLAGS[@]}" \
  --prefix="$PREFIX"

# -----------------------------
# Build
# -----------------------------
echo "Building"
CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu || echo 2)
make -j"$CORES"

# -----------------------------
# Install to prefix
# -----------------------------
echo "Installing to $PREFIX"
make install

echo "Installed files in $PREFIX/bin:"
ls -lah "$PREFIX/bin"

# -----------------------------
# Collect artifacts
# -----------------------------
mkdir -p ../artifact

if [[ "$OS" == MINGW* || "$OS" == MSYS* ]]; then
  cp "$PREFIX/bin/ffmpeg.exe" ../artifact/
  cp "$PREFIX/bin/ffprobe.exe" ../artifact/
else
  cp "$PREFIX/bin/ffmpeg" ../artifact/
  cp "$PREFIX/bin/ffprobe" ../artifact/
fi

echo "Artifacts:"
ls -lah ../artifact

echo "Done :)"
