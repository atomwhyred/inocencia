#!/usr/bin/env bash
# Compila la release de inocencIA, una arquitectura detras de otra, y deja los APK con el
# nombre de la app en build/inocencIA/ (listos para compartir).
#
#   ./tools/build_apks.sh 3                       # build number 3, todas las arquitecturas
#   ./tools/build_apks.sh 3 arm64-v8a             # solo esa
#   ./tools/build_apks.sh 3 arm64-v8a armeabi-v7a
#
# Arquitecturas: arm64-v8a (casi todos los moviles), armeabi-v7a (32 bits, sin probar en un
# telefono real) y x86_64 (emuladores). Flutter los llama app-<abi>-release.apk y no se puede
# cambiar sin romper su busqueda del resultado, asi que aqui se copian con otro nombre.
#
# Sube siempre el build number respecto a lo instalado: asi se actualiza sin desinstalar
# (desinstalar borra perfiles, historial y medallas).
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ"

if [[ $# -lt 1 || ! $1 =~ ^[0-9]+$ ]]; then
  echo "Uso: $0 <build_number> [arm64-v8a] [armeabi-v7a] [x86_64]" >&2
  exit 1
fi
NUMERO="$1"
shift
ABIS=("$@")
[[ ${#ABIS[@]} -eq 0 ]] && ABIS=(arm64-v8a armeabi-v7a x86_64)

VERSION="$(grep -m1 '^version:' pubspec.yaml | sed -E 's/^version:[[:space:]]*([0-9.]+).*/\1/')"
SALIDA=build/inocencIA
mkdir -p "$SALIDA"

plataforma() {
  case "$1" in
    arm64-v8a) echo android-arm64 ;;
    armeabi-v7a) echo android-arm ;;
    x86_64) echo android-x64 ;;
    *) echo "Arquitectura desconocida: $1" >&2; return 1 ;;
  esac
}

for abi in "${ABIS[@]}"; do
  destino="$SALIDA/inocencIA-$VERSION-$abi.apk"
  echo "=== $abi (build $NUMERO) ==="
  flutter build apk --release --split-per-abi \
    --target-platform "$(plataforma "$abi")" --build-number "$NUMERO"
  cp -f "build/app/outputs/flutter-apk/app-$abi-release.apk" "$destino"
  echo "-> $destino ($(du -h "$destino" | cut -f1))"
done

(cd "$SALIDA" && sha256sum inocencIA-*.apk > SHA256SUMS)
echo
echo "Listo. Archivos en $SALIDA:"
ls -lh "$SALIDA"
