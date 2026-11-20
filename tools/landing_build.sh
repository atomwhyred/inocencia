#!/usr/bin/env bash
# Empaqueta la escena 3D de la landing (Toco con three.js) y prepara sus imágenes.
#   ./tools/landing_build.sh
# Salida (se commitea; GitHub Pages publica landing/ tal cual):
#   landing/js/escena.js        three.js con solo lo que se usa + landing-src/escena.js
#   landing/img/toco/*.webp     capas de Toco sacadas de assets/mascot/
set -euo pipefail
cd "$(dirname "$0")/.."

(cd landing-src && npm ci --no-audit --no-fund --silent)

mkdir -p landing/js landing/img/toco
landing-src/node_modules/.bin/esbuild landing-src/escena.js \
  --bundle --minify --format=esm --target=es2020 --legal-comments=eof \
  --outfile=landing/js/escena.js

for capa in tail body wing branch head eye; do
  cwebp -quiet -q 85 -alpha_q 90 "assets/mascot/$capa.png" -o "landing/img/toco/$capa.webp"
done

du -ch landing/js/escena.js landing/img/toco/*.webp | tail -1
