# 2. Descargar e instalar

Todo lo necesario está en el **canal de Telegram**. Se descarga **una sola vez**. Después la app funciona sin
internet, y los archivos se pueden pasar a otros teléfonos sin internet (ver más abajo).

## Qué archivos buscar en el canal

Hacen falta **4 cosas**:

1. **La app**: un archivo que empieza por **inocencIA** y termina en **`.apk`**, por ejemplo
   `inocencIA-1.0.1-arm64-v8a.apk`.
   - Si en el canal hay varias versiones, coge **la más nueva**.
   - Si hay una que dice **arm64**, es la de casi todos los teléfonos actuales. La que dice **armeabi-v7a** es
     solo para teléfonos viejos de 32 bits.
2. **El modelo de IA** (el "cerebro" del tutor): un archivo que termina en **`.gguf`**. Hay varios; elige uno
   según la memoria RAM del teléfono (ver la lista de abajo).
3. **La base de libros**: el archivo **`knowledge.db`**. Es lo que el tutor consulta para responder. También trae
   las preguntas del juego.
4. **Los libros en PDF** (por ejemplo `4to_matematica.pdf`). Son para que el niño los lea en **Libros**. Basta con
   bajar los del grado de tus niños.

## Qué modelo elegir

- **Teléfono con 8 GB de RAM o más** → `qwen2.5-3b-instruct-q4_0.gguf` (unos 2 GB). **Es el recomendado.**
  Responde bien y apoyado en el libro.
- **Teléfono con menos de 8 GB** → `qwen2.5-1.5b-instruct-q4_k_m.gguf` (unos 1,1 GB). Va más rápido pero se
  equivoca más.
- `qwen2.5-7b-instruct-q4_k_m.gguf` (4,7 GB) **no se recomienda**: aunque el teléfono tenga 12 GB, tarda más de
  un minuto en empezar a responder.

¿No sabes cuánta RAM tiene? Instala la app y entra en **Zona de padres → Archivos**: la app te dice qué modelo
le conviene a ese teléfono.

## Instalar la app

1. Abre el archivo `.apk` desde Telegram o desde la carpeta de **Descargas**.
2. Android preguntará si permites instalar apps de **origen desconocido**. Acéptalo para Telegram (o para el
   gestor de archivos).
3. Pulsa **Instalar**.

Para **actualizar** la app, instala el `.apk` nuevo **encima**, sin desinstalar la anterior. **Desinstalar borra
los perfiles, el historial y las medallas.** Cada actualización lleva un número de versión nuevo en el nombre del
archivo (`inocencIA-1.0.1-…`, `inocencIA-1.0.2-…`): coge siempre el más alto.

**Una sola vez** hará falta desinstalar: la primera versión firmada con la clave propia de inocencIA no se puede poner
encima de las anteriores, porque Android no deja cambiar la firma de una app. Antes, anota tus perfiles (se
vuelven a crear en un minuto). Después ya se actualiza siempre encima.

¿Quieres comprobar que el archivo es el original? En el canal va junto a cada versión el archivo `SHA256SUMS`, con la
huella de cada `.apk`; debe coincidir con la que calcula tu gestor de archivos.

## Dónde copiar los archivos

Con un gestor de archivos (o por cable desde el ordenador), copia:

- el modelo `.gguf` y `knowledge.db` a la carpeta
  **`Android/data/com.inocencia.app/files/`**
- los PDF de los libros a la carpeta
  **`Android/data/com.inocencia.app/files/libros/`** (créala si no existe)

La carpeta `com.inocencia.app` aparece después de abrir la app **una vez**. Puede estar en la memoria interna o
en la tarjeta SD.

> En Android 11 o superior muchos gestores de archivos no dejan entrar en `Android/data`. Usa el gestor de
> archivos que trae el teléfono ("Archivos" de Google o el de Xiaomi/Samsung) o cópialos por cable desde un
> ordenador.

**Si no puedes entrar en esa carpeta**: deja los PDF donde estén (Descargas, tarjeta SD...). En el paso
siguiente la app te deja buscarlos con **Buscar carpeta**.

Después sigue con [3. Primeros pasos](03-primeros-pasos.md) para que la app encuentre los archivos.

## Pasar los archivos a otro teléfono sin internet

Cuando un teléfono ya tiene todo, puede pasárselo a otro:

1. En el teléfono que ya lo tiene: **Zona de padres → Archivos**.
2. Junto al modelo, la base o los libros, pulsa **Compartir** (por Bluetooth, Wi-Fi Direct, Quick Share, Telegram...)
   o **Copiar a…** (por ejemplo, a una tarjeta SD o a una memoria USB).
3. En el otro teléfono, copia lo recibido a las carpetas de arriba y sigue con los primeros pasos.

Ojo: el modelo pesa mucho (1-2 GB). Por Bluetooth tarda bastante; mejor por tarjeta SD, cable o Quick Share.

Siguiente: [3. Primeros pasos](03-primeros-pasos.md)
