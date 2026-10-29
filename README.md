# inocencIA

Tutor virtual **sin internet** para niños cubanos de 1.º a 6.º grado. Una IA local (llama.cpp) responde con el
contenido de los libros de texto del grado del niño, paso a paso y sin dar la respuesta de golpe.
App Flutter para **Android 10+**, en móviles y tablets. Nombre de la app: `inocencIA` · id `com.inocencia.app`.

## Qué hace

- **Perfiles de niños** con grado, y **zona de padres** protegida con PIN.
- **Mi tutor**: chat con un modelo Qwen2.5 local (GGUF) que busca antes en los libros (RAG con SQLite FTS5) y cita
  la página. Historial por niño.
- **Toco**, el tocororo mascota: animado en el chat, da ánimos al tocarlo.
- **Mis libros**: lector de los PDF originales, con la página guardada.
- **Pomodoro infantil**: 15+5 min (1.º a 3.º) o 20+5 min (4.º a 6.º); durante el descanso el chat se bloquea.
- **Lectura en voz alta** de las respuestas (voz del dispositivo; hace falta instalar la voz en español).
- **Quiz** de 3 preguntas sobre el último tema y **medallas** guardadas por niño ("Mis medallas").
- **Modo batería / apagón**: tema negro puro, sin animaciones y tutor ligero (2 hilos, respuestas más cortas);
  se activa a mano y la app lo sugiere por debajo del 20 % de batería.
- **Recordatorios** de estudio y exportar/compartir sin internet el modelo, la base y los libros.

## Lo que NO está en el repositorio

Por tamaño y derechos de autor, estos archivos hay que ponerlos aparte (ver `.gitignore`):

| Qué | Dónde se usa | Cómo obtenerlo |
|---|---|---|
| Modelo `*.gguf` | Zona de padres → Archivos | Ver [docs/models.md](docs/models.md) (Qwen2.5 1.5B / 3B / 7B) |
| `libros/` (PDF de los libros de texto) | Mis libros y base de conocimiento | Ver [docs/libros.md](docs/libros.md) |
| `knowledge.db` | El tutor | `tools/knowledge_builder/build_knowledge_db.py` a partir de los libros; esquema en [docs/knowledge_db_schema.md](docs/knowledge_db_schema.md) |
| `android/app/src/main/jniLibs/` | llama.cpp compilado | `native/llama/build_android.sh` (necesita NDK y CMake) |

Los libros de texto tienen derechos de autor: no los subas a un repositorio público.

## Compilar

Requisitos: Flutter estable (Dart 3.13), Android SDK/NDK, y las `.so` de llama.cpp en `jniLibs` (paso anterior).

```bash
flutter pub get
dart run build_runner build      # regenera lib/core/storage/app_database.g.dart si cambias las tablas
flutter analyze && flutter test  # los tests compilan PDFium (pdfrx): necesitan clang
flutter run                      # en un dispositivo conectado
```

APK de release, uno por arquitectura (arm64 para móviles y tablets actuales, armeabi-v7a para los de 32 bits;
hay que compilar antes las `.so` de las dos con `native/llama/build_android.sh arm64-v8a` y `... armeabi-v7a`):

```bash
flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --build-number <N>
```

Sube siempre `--build-number` para poder actualizar sobre una instalación anterior sin desinstalar
(se perderían los datos de los niños). El APK de release sale **firmado con la clave de depuración**: para
publicarlo en una tienda hay que crear una clave propia (ver [docs/pendiente.md](docs/pendiente.md)).

## Estructura

Clean Architecture por funcionalidades en `lib/features/` (`auth`, `tutor`, `knowledge`, `books`, `mascot`,
`pomodoro`, `speech`, `quiz`, `achievements`, `power`, ...), con Riverpod, go_router y Drift. Lo común está en
`lib/core/`. Herramientas auxiliares en `tools/` y el código nativo en `native/llama/`.

## Documentación

- [docs/guia-padres.md](docs/guia-padres.md): guía para padres (instalar, copiar modelo y libros, perfiles).
- [docs/pendiente.md](docs/pendiente.md): estado actual y lo que falta.
- [docs/models.md](docs/models.md): modelos probados y mediciones en un Pixel 6.
- [docs/libros.md](docs/libros.md): cómo dar los libros a la app.
- [docs/mascota.md](docs/mascota.md): Toco y sus capas.
- [docs/knowledge_db_schema.md](docs/knowledge_db_schema.md): base de conocimiento.

## Licencia

Sin definir todavía: añade un archivo `LICENSE` antes de publicar. Los modelos Qwen tienen sus propias licencias
(el de 3B usa la licencia Qwen Research).
