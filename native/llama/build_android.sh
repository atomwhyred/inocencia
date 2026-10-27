#!/usr/bin/env bash
# Compila llama.cpp para Android (solo CPU) y copia las .so a jniLibs.
#
#   native/llama/build_android.sh [abi] [arm_arch]
#
#   abi       arm64-v8a (por defecto) o armeabi-v7a
#   arm_arch  opcional, p. ej. armv8.2-a+dotprod (mas rapido, pero NO arranca en
#             CPU sin dotprod como Cortex-A53/A73). Sin el, se compila para el
#             armv8-a base, que funciona en cualquier arm64.
#
# El codigo de llama.cpp va fijado al commit que espera llama_cpp_dart 0.2.2
# (ver LLAMA_CPP_COMMIT) y se descarga en native/llama/src/llama.cpp.
set -euo pipefail

LLAMA_CPP_COMMIT=4ffc47cb2001e7d523f9ff525335bbe34b1a2858
ABI="${1:-arm64-v8a}"
ARM_ARCH="${2:-}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SRC="$HERE/src/llama.cpp"
BUILD="$HERE/build/$ABI${ARM_ARCH:+-$ARM_ARCH}"
OUT="$ROOT/android/app/src/main/jniLibs/$ABI"

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
NDK="${ANDROID_NDK_HOME:-$(ls -d "$SDK"/ndk/* | sort -V | tail -1)}"
CMAKE_BIN="$(ls -d "$SDK"/cmake/*/bin | sort -V | tail -1)"
export PATH="$CMAKE_BIN:$PATH"

if [ ! -f "$SRC/CMakeLists.txt" ]; then
  echo "Descargando llama.cpp @ ${LLAMA_CPP_COMMIT:0:10}..."
  mkdir -p "$SRC"
  git -C "$SRC" init -q
  git -C "$SRC" remote add origin https://github.com/ggml-org/llama.cpp
  git -C "$SRC" fetch -q --depth 1 origin "$LLAMA_CPP_COMMIT"
  git -C "$SRC" checkout -q FETCH_HEAD
fi
if [ "$(git -C "$SRC" rev-parse HEAD)" != "$LLAMA_CPP_COMMIT" ]; then
  echo "llama.cpp no esta en el commit esperado ($LLAMA_CPP_COMMIT)" >&2
  exit 1
fi

ARGS=(
  -G Ninja
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake"
  -DANDROID_ABI="$ABI"
  -DANDROID_PLATFORM=android-29
  -DANDROID_STL=c++_shared
  -DCMAKE_BUILD_TYPE=Release
  -DBUILD_SHARED_LIBS=ON
  -DLLAMA_CURL=OFF
  -DLLAMA_BUILD_TESTS=OFF
  -DLLAMA_BUILD_EXAMPLES=OFF
  -DLLAMA_BUILD_SERVER=OFF
  -DLLAMA_BUILD_TOOLS=ON
  # llama_cpp_dart no llama a ggml_backend_load_all() en Android: el backend de
  # CPU tiene que ir enlazado dentro de libggml, no como .so dinamico.
  -DGGML_BACKEND_DL=OFF
  -DGGML_OPENMP=OFF
  -DGGML_NATIVE=OFF
)
[ -n "$ARM_ARCH" ] && ARGS+=(-DGGML_CPU_ARM_ARCH="$ARM_ARCH")

echo "NDK: $NDK"
echo "ABI: $ABI ${ARM_ARCH:+($ARM_ARCH)}"
cmake -S "$SRC" -B "$BUILD" "${ARGS[@]}"
# libmtmd.so es la que abre el binding (exporta llama + mtmd).
cmake --build "$BUILD" --target mtmd llama ggml -j"$(nproc)"

mkdir -p "$OUT"
rm -f "$OUT"/*.so
find "$BUILD" -name '*.so' -path '*bin*' -exec cp -v {} "$OUT"/ \;
case "$ABI" in
  arm64-v8a)   TRIPLE=aarch64-linux-android ;;
  armeabi-v7a) TRIPLE=arm-linux-androideabi ;;
  *) echo "ABI no soportada: $ABI" >&2; exit 1 ;;
esac
cp -v "$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$TRIPLE/libc++_shared.so" "$OUT"/
ls -la "$OUT"
