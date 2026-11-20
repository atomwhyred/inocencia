#!/usr/bin/env bash
# Crea la clave propia para firmar las releases de inocencIA y android/key.properties.
#
#   ./tools/crear_keystore.sh
#
# IMPORTANTE:
# - Haz una copia de seguridad del keystore y de las contraseñas FUERA de este ordenador
#   (memoria USB, gestor de contraseñas). Si se pierden, no se podrán publicar
#   actualizaciones: habría que desinstalar en cada teléfono y se borrarían los perfiles.
# - Ni el keystore ni key.properties se suben a git (android/.gitignore).
# - Cambiar de la clave de depuración a esta obliga a desinstalar UNA vez la app en los
#   teléfonos que tengan una versión firmada con la de depuración.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${INOCENCIA_KEYSTORE:-$HOME/.inocencia/inocencia-release.jks}"
ALIAS=inocencia

if [[ -f "$RAIZ/android/key.properties" ]]; then
  echo "Ya existe android/key.properties: no se toca." >&2
  exit 1
fi
if [[ -f "$DESTINO" ]]; then
  echo "Ya existe $DESTINO: no se sobrescribe." >&2
  exit 1
fi
command -v keytool >/dev/null || { echo "Falta keytool (viene con el JDK de Android Studio)." >&2; exit 1; }

mkdir -p "$(dirname "$DESTINO")"
chmod 700 "$(dirname "$DESTINO")"
read -r -s -p "Contraseña nueva para el keystore (mínimo 12 caracteres): " PASS; echo
read -r -s -p "Repítela: " PASS2; echo
[[ "$PASS" == "$PASS2" ]] || { echo "No coinciden." >&2; exit 1; }
[[ ${#PASS} -ge 12 ]] || { echo "Demasiado corta." >&2; exit 1; }

# 30 años de validez; RSA 4096. El nombre que aparece en el certificado es genérico.
keytool -genkeypair -v -keystore "$DESTINO" -alias "$ALIAS" -keyalg RSA -keysize 4096 \
  -validity 10950 -storepass "$PASS" -keypass "$PASS" -dname "CN=inocencIA, O=inocencIA"
chmod 600 "$DESTINO"

umask 077
cat > "$RAIZ/android/key.properties" <<PROPS
storeFile=$DESTINO
storePassword=$PASS
keyAlias=$ALIAS
keyPassword=$PASS
PROPS

echo
echo "Listo: $DESTINO y android/key.properties."
echo "Huella SHA-256 del certificado (publícala junto a los APK para que se pueda comprobar):"
keytool -list -v -keystore "$DESTINO" -storepass "$PASS" -alias "$ALIAS" | grep -m1 "SHA256:"
echo
echo "AHORA: copia $DESTINO y la contraseña a un lugar seguro fuera de este ordenador."
