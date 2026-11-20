# Publicar en GitHub: código, versiones y la web

Guía paso a paso para subir inocencIA a GitHub, publicar los APK y tener la web en GitHub Pages en
**https://atomwhyred.github.io/inocencia/**. Se hace una vez; al final están los pasos de cada actualización.

Nombres que ya usa el proyecto (la web enlaza a ellos):

| Qué | Valor |
|---|---|
| Repositorio | `github.com/atomwhyred/inocencia` |
| Web | `https://atomwhyred.github.io/inocencia/` |
| Descargas | `github.com/atomwhyred/inocencia/releases/latest` |
| Telegram | `t.me/elrincondeatomwhyred` |

Todos los comandos se ejecutan en la carpeta del proyecto. `gh` (GitHub CLI) ya tiene la sesión iniciada como
`atomwhyred`; si no, `gh auth login`.

## 0. Antes de hacerlo público (comprobado el 20-nov-2026)

- **No hay secretos ni archivos grandes en el repositorio**: `key.properties`, `*.jks`/`*.keystore`, los modelos
  `*.gguf`, `knowledge.db`, los PDF de los libros y los APK están en `.gitignore`. El repositorio pesa unos 2 MB.
  Compruébalo otra vez justo antes con:
  ```bash
  git ls-files | grep -iE '\.(jks|keystore|gguf|db|apk)$|key\.properties'   # no debe salir nada
  ```
- **Tu correo personal sale en los commits.** Todos llevan `elrincondeatom@gmail.com` como autor, y en un repositorio
  público cualquiera puede verlo. Si prefieres ocultarlo, antes del primer `push` cambia el autor de todos los commits
  por tu correo privado de GitHub (solo es seguro ahora, mientras el historial no está subido):
  ```bash
  git -c user.name=atomwhyred -c user.email=36234489+atomwhyred@users.noreply.github.com \
      rebase -r --root --exec 'git commit --amend --no-edit --reset-author'
  git config user.name atomwhyred
  git config user.email 36234489+atomwhyred@users.noreply.github.com
  ```
  Y en GitHub: *Settings › Emails › Keep my email addresses private*.
- **Los libros de texto tienen derechos de autor**: no los subas al repositorio ni a las versiones salvo que tengas
  permiso para distribuirlos (ver "Qué NO incluye este repositorio" en [docs/desarrollo.md](desarrollo.md)).

## 1. Crear el repositorio y subir el código

El trabajo está en la rama `master`, pero la web se publica desde `main` (`.github/workflows/pages.yml`). Se renombra
la rama y se sube:

```bash
git branch -m master main
gh repo create atomwhyred/inocencia --public --source=. --remote=origin \
  --description "Tutor con IA que funciona sin internet para niños de 1.º a 6.º grado"
git push -u origin main
```

## 2. Activar GitHub Pages (la web)

Una vez, desde el navegador: **Settings › Pages › Build and deployment › Source: GitHub Actions**.
O desde la terminal:

```bash
gh api -X POST repos/atomwhyred/inocencia/pages -f build_type=workflow
gh workflow run pages.yml          # primera publicación (luego se publica sola)
gh run watch                       # esperar a que termine
```

La web queda en **https://atomwhyred.github.io/inocencia/** (tarda un par de minutos la primera vez). A partir de ahí,
cada `git push` a `main` que cambie algo de `landing/` la vuelve a publicar sola.

Pruébala en un móvil: Toco sale del libro, el botón ☀️/🌙, los enlaces de descarga (darán 404 hasta el paso 3).

## 3. Publicar la primera versión (los APK)

1. **Clave de firma propia** (una vez en la vida del proyecto):
   ```bash
   ./tools/crear_keystore.sh
   ```
   Guarda una copia de `~/.inocencia/inocencia-release.jks` y de `android/key.properties` **fuera del ordenador**
   (memoria USB, nube privada). Si se pierde, ninguna versión futura se podrá instalar encima de las anteriores.
2. **Subir la versión** en `pubspec.yaml` (`version: 1.0.2+6`, ver "Compilar la release" en [docs/desarrollo.md](desarrollo.md)) y compilar:
   ```bash
   ./tools/build_apks.sh 6
   ```
   Deja los APK y `SHA256SUMS` en `build/inocencIA/` y los símbolos en `build/simbolos/1.0.2+6/` (guárdalos: sirven
   para leer un fallo).
3. **Crear la versión en GitHub** con los APK:
   ```bash
   gh release create v1.0.2 build/inocencIA/inocencIA-1.0.2-*.apk build/inocencIA/SHA256SUMS \
     --title "inocencIA 1.0.2" --notes "Primera versión pública."
   ```
   El enlace de la web `releases/latest` lleva siempre a la última.
4. **Modelo y base de libros** (opcional): se pueden adjuntar a la misma versión (`gh release upload v1.0.2 <archivo>`).
   GitHub admite archivos de hasta 2 GB cada uno; el modelo de 3B (≈ 2,0 GB) entra justo, el de 7B no. Si cambias el
   modelo o la base, regenera la lista de archivos oficiales (`python3 tools/official_files.py …`) antes de compilar.

> La primera versión firmada con la clave propia no se instala encima de las de prueba (firmadas con la clave de
> depuración): en los teléfonos de prueba hay que desinstalar una vez, y eso borra perfiles e historial.

## 4. Anunciarlo

- Comparte el enlace de la web en el canal de Telegram. La vista previa usa `landing/img/compartir.jpg`.
- Para comprobar cómo se ve la vista previa, pega el enlace en un chat contigo mismo en Telegram.

## Cada actualización

```bash
# 1. subir la versión en pubspec.yaml (1.0.3+7…) y compilar
./tools/build_apks.sh 7
# 2. subir el código
git push
# 3. publicar los APK
gh release create v1.0.3 build/inocencIA/inocencIA-1.0.3-*.apk build/inocencIA/SHA256SUMS \
  --title "inocencIA 1.0.3" --notes "Qué cambia…"
```

Si cambias la escena 3D de la web (`landing-src/escena.js`), ejecuta antes `./tools/landing_build.sh` y súbelo
también: GitHub Pages publica `landing/` tal cual, sin compilar nada.

## Dominio propio (opcional)

Crea `landing/CNAME` con el dominio (por ejemplo `inocencia.app`), configura el DNS como indica
*Settings › Pages › Custom domain* y cambia en `landing/index.html` las direcciones de `og:url`, `og:image` y
`canonical`.
