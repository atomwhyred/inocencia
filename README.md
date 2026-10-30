# inocencIA

**Tutor virtual que funciona sin internet para niños cubanos de 1.º a 6.º grado.**
Una inteligencia artificial que corre dentro del teléfono o la tablet responde a las dudas del niño usando el
contenido de sus propios libros de texto, y lo guía paso a paso en lugar de darle la respuesta hecha.

- App Flutter para **Android 10 o superior** (móviles y tablets, 64 y 32 bits).
- Nombre visible: `inocencIA` · identificador: `com.inocencia.app`.
- **100 % local**: no envía nada a ningún servidor. La versión release no pide permiso de internet.

> **Estado:** versión de pruebas (1.0). Probada en un Pixel 6 (8 GB) y en una Xiaomi Pad 5. La versión de 32 bits
> compila pero no se ha probado en un teléfono real. Lo que falta está en [docs/pendiente.md](docs/pendiente.md).

---

## Índice

1. [Por qué existe](#por-qué-existe)
2. [Qué hace](#qué-hace)
3. [Cómo funciona por dentro](#cómo-funciona-por-dentro)
4. [Qué NO incluye este repositorio](#qué-no-incluye-este-repositorio)
5. [Requisitos](#requisitos)
6. [Puesta en marcha para desarrolladores](#puesta-en-marcha-para-desarrolladores)
7. [Preparar los datos: libros, base y modelo](#preparar-los-datos-libros-base-y-modelo)
8. [Compilar la release](#compilar-la-release)
9. [Instalar en un dispositivo y usarlo](#instalar-en-un-dispositivo-y-usarlo)
10. [Estructura del código](#estructura-del-código)
11. [Pruebas](#pruebas)
12. [Privacidad y seguridad](#privacidad-y-seguridad)
13. [Rendimiento y límites conocidos](#rendimiento-y-límites-conocidos)
14. [Documentación](#documentación)
15. [Contribuir](#contribuir)
16. [Licencia y créditos](#licencia-y-créditos)

---

## Por qué existe

En muchos hogares no hay internet estable, o no se quiere que un niño navegue solo. inocencIA lleva un tutor al
dispositivo sin conexión: el niño pregunta lo que no entiende de su libro, y el tutor le explica con las palabras
y el orden del libro cubano de su grado, citando la página.

Decisiones de diseño:

- **Sin internet, sin cuentas, sin anuncios.** Todo se guarda en el dispositivo.
- **Pedagogía antes que respuesta.** El tutor da *un* paso y hace *una* pregunta; ante un ejercicio no lo
  resuelve, pide el primer paso. Si el niño contesta, valora la respuesta y corrige con suavidad.
- **Fiel al libro.** Solo usa los textos recuperados del libro del grado del niño; si el libro no lo explica, lo
  dice y sugiere preguntar al maestro.
- **Hecho para el padre o la madre.** La zona de padres (con PIN) controla perfiles, archivos y ajustes.

## Qué hace

### Para el niño

| Función | Descripción |
|---|---|
| **Perfiles** | Cada niño tiene nombre, avatar y grado (1.º a 6.º; el grado sube solo con los años). Historial, página de lectura y medallas son por niño. Un perfil puede tener su propio PIN. |
| **Mi tutor** | Chat con un modelo de lenguaje local. Busca antes en los libros, responde con 2-3 frases, termina con una pregunta que se puede contestar con un toque y muestra de qué libro y página sale cada respuesta (con enlace para abrir el PDF). |
| **Toco** | Un tocororo (ave nacional de Cuba) animado por capas, en la barra superior del chat. Duerme mientras carga el modelo, piensa mientras responde, se alegra o anima según el acierto del niño, y al tocarlo da un gesto y un mensaje de ánimo. |
| **Mis libros** | Lector de los PDF originales (imágenes, tablas, ejercicios). Recuerda la página de cada niño en cada libro. |
| **Lectura en voz alta** | Un botón con altavoz en cada respuesta la lee (reproducir, pausar, parar) con la voz del dispositivo. Solo suena un mensaje a la vez. |
| **Quiz** | Tres preguntas de opción múltiple sobre el último tema, generadas por el modelo local a partir del texto del libro (se descartan las que no se apoyan en él). |
| **Mis tarjetas** (flashcards) | Tarjetas de memoria de doble cara: pregunta al frente y respuesta al reverso al pulsar. El botón «Crear tarjetas» bajo una respuesta del tutor pide al modelo local 3-4 tarjetas del tema (solo se guardan las apoyadas en el texto del libro). Repaso con «La sabía» / «A repasar» (las falladas vuelven al final, hasta dos veces); se guarda cuántas veces la sabía. Por niño y sin internet. |
| **Mis medallas** | Siete medallas fijas (primer tema, primer quiz, 5 y 20 aciertos, quiz perfecto, sesión de estudio completada, tres días seguidos) y una estrella por acierto. Se guardan en SQLite. |
| **Pomodoro infantil** | Estudio + descanso: 15+5 min de 1.º a 3.º y 20+5 min de 4.º a 6.º. En el descanso el chat se bloquea, Toco queda en el centro con la cuenta atrás y solo se vuelve con su mensaje. |
| **Modo batería / apagón** | Tema negro puro, Toco y animaciones quietos y tutor ligero (2 hilos de CPU, respuestas más cortas). Se activa a mano con el icono de batería; por debajo del 20 % sin cargador la app lo *sugiere*, nunca lo activa sola. |

### Para el padre o la madre (Zona de padres)

- **Perfiles**: crear, editar y borrar niños.
- **Archivos**: vincular el modelo de IA, la base de libros y la carpeta de PDF; recomendación de modelo según la
  RAM; **compartir o copiar** esos archivos a otro dispositivo sin internet.
- **Apariencia**: tema claro/oscuro, mascota, Pomodoro, lectura en voz alta y modo batería.
- **Avisos**: recordatorios de estudio (varios, cada uno con su interruptor).
- **Diagnóstico del tutor** (Zona de padres → Archivos): modelo, hilos, CPU y velocidad de la última respuesta, con
  botón para copiarlo (sin datos personales); útil cuando el tutor va lento.
- Entrada protegida con PIN de 4 o 6 dígitos y bloqueo tras varios intentos fallidos.

Guía paso a paso para familias: [docs/guia-padres.md](docs/guia-padres.md).

## Cómo funciona por dentro

```
Pregunta del niño
      │
      ▼
 Búsqueda en knowledge.db ── SQLite FTS5 (bm25), filtro ESTRICTO por grado, sin tildes
      │  5 fragmentos del libro (~1500 caracteres)
      ▼
 Prompt: reglas pedagógicas + textos del libro + últimos turnos + la pregunta
      │
      ▼
 llama.cpp (modelo Qwen2.5 GGUF cuantizado Q4_K_M) en un isolate propio
      │  streaming de tokens; se corta tras la primera pregunta del tutor
      ▼
 Respuesta + fuentes (libro y página) → chat → (opcional) voz → medallas
```

Piezas importantes:

- **RAG offline.** `knowledge.db` es un SQLite de solo lectura con fragmentos de ~700 caracteres, su grado,
  asignatura, libro y página, e índice FTS5 con `remove_diacritics` para que «fracción» y «fraccion» coincidan.
  Contrato completo en [docs/knowledge_db_schema.md](docs/knowledge_db_schema.md).
- **Inferencia local.** `llama_cpp_dart` sobre llama.cpp compilado para Android (solo CPU). En arm64 se compilan
  todas las variantes de CPU (`libggml-cpu-android_armv8.0` … `armv9.2`) y la app carga en tiempo de ejecución la
  mejor que soporte el teléfono, así que el mismo APK es seguro en un Cortex-A53 y rápido en un Tensor reciente.
- **Caché del prefijo.** El mensaje de sistema se procesa una sola vez por sesión y grado, y cada turno reutiliza
  ese estado (ahorra 5-10 s por turno). Ver mediciones en [docs/models.md](docs/models.md).
- **Flashcards.** Misma estrategia que el quiz: texto plano (`T1:`/`R:`), parser tolerante, filtro de fidelidad por raíz de palabra contra el libro, tarjetas guardadas según llegan en SQLite (tabla `flashcards`, esquema v4). El generador es una interfaz (`FlashcardGenerator`) para poder cambiar de motor.
- **Quiz sin JSON.** Un modelo de 3B falla con JSON, así que el quiz usa texto plano (`P1:`, `A) B) C)`,
  `RESPUESTA:`) con un parser tolerante, se barajan las opciones y se comprueba que la respuesta correcta salga
  del texto del libro.
- **Medallas.** Catálogo fijo en código; el servicio registra eventos, actualiza contadores en SQLite (Drift) y
  anuncia las medallas nuevas con un aviso.
- **Sin temporizadores en la lógica.** El Pomodoro, la batería y las animaciones se inyectan como proveedores y los
  tests los reemplazan, de modo que `pumpAndSettle` funciona.

Tecnologías: Flutter 3.x / Dart 3.13, Riverpod 3, go_router, Drift (SQLite), `llama_cpp_dart`, `pdfrx` (PDFium),
`flutter_tts`, `battery_plus`, `flutter_local_notifications`, `flutter_secure_storage`.

## Qué NO incluye este repositorio

Por tamaño y por derechos de autor, estos archivos hay que prepararlos aparte (están en `.gitignore`):

| Qué | Para qué | Cómo obtenerlo |
|---|---|---|
| Modelo `*.gguf` | La IA del tutor | Descargarlo de Hugging Face: [docs/models.md](docs/models.md) |
| `libros/` (PDF) | Leer los libros y construir la base | Los aporta quien despliegue la app: [docs/libros.md](docs/libros.md) |
| `knowledge.db` | Base de conocimiento del tutor | Se genera con `tools/knowledge_builder` (ver abajo) |
| `android/app/src/main/jniLibs/` | llama.cpp compilado | `native/llama/build_android.sh` (ver abajo) |

> **Los libros de texto tienen derechos de autor.** Este repositorio no los incluye ni debe incluirlos. Quien use
> el proyecto debe tener derecho a usar los libros que cargue.

## Requisitos

**Para usar la app (dispositivo):**
- Android 10 (API 29) o superior; móvil o tablet.
- RAM orientativa: 1.5B → cualquier teléfono con 3 GB o más; 3B → 7-8 GB; 7B → 12 GB.
- Espacio: el modelo (1,1 a 4,7 GB), la base de libros y los PDF (varios cientos de MB).

**Para compilar (ordenador Linux/macOS):**
- Flutter estable con Dart `^3.13.5` y Android SDK.
- Para las librerías nativas: Android NDK (probado con 28.2), CMake y Ninja, y `git`.
- Para ejecutar los tests: `clang` (`pdfrx` compila PDFium).
- Para construir la base de libros: Python 3, `poppler` (`pdftotext`, `pdftoppm`) y `tesseract` con los idiomas
  `spa` y `eng` (solo para libros escaneados).

## Puesta en marcha para desarrolladores

```bash
git clone <url-del-repositorio>
cd DeepTutor            # o el nombre que tenga la carpeta
flutter pub get

# 1) Librerías nativas de llama.cpp (una vez; tardan unos minutos)
native/llama/build_android.sh arm64-v8a      # móviles y tablets actuales
native/llama/build_android.sh armeabi-v7a    # opcional: teléfonos de 32 bits

# 2) Código generado de la base de datos (solo si cambias las tablas)
dart run build_runner build

# 3) Comprobar y ejecutar
flutter analyze
flutter test
flutter run                                   # con un dispositivo conectado por USB
```

El script `build_android.sh` descarga llama.cpp fijado al commit que espera `llama_cpp_dart` y copia las `.so` a
`android/app/src/main/jniLibs/<abi>/`. En 32 bits desactiva `llamafile`, que no compila en armv7.

## Preparar los datos: libros, base y modelo

### 1. Los libros (PDF)

Nómbralos con el grado al principio; de ahí salen el grado y la asignatura:

```
1ro_lengua.pdf   2do_ct_matematica.pdf   6to_ciencias_naturales.pdf   1ro_2do_ca_el_mundo.pdf
```

(`ct` = cuaderno de trabajo). Ponlos en la carpeta `libros/`. Detalles y manera de dárselos a la app en
[docs/libros.md](docs/libros.md).

### 2. La base de conocimiento

```bash
python3 tools/knowledge_builder/build_knowledge_db.py --books libros --out build/knowledge.db
```

Extrae el texto de cada página con `pdftotext`, pasa por OCR (`tesseract`, en paralelo y con caché) las páginas
sin texto, lo limpia, lo trocea y lo indexa con FTS5. Hay tests en `tools/knowledge_builder/`.

### 3. El modelo de IA

Formato GGUF, cuantización Q4_K_M. Modelos probados:

| Modelo | Tamaño | RAM del teléfono | Notas |
|---|---|---|---|
| Qwen2.5-1.5B-Instruct | 1,1 GB | ≥ 3 GB | Rápido (~26 s/respuesta en un Pixel 6) pero se equivoca más. |
| Qwen2.5-3B-Instruct | 2,1 GB | ≥ 7 GB | Recomendado: fiel al libro, ~30-40 s por respuesta. |
| Qwen2.5-7B-Instruct | 4,7 GB | ≥ 10 GB | Sin medir. |

Enlaces, licencias (el de 3B usa la licencia Qwen Research: revísala antes de distribuirlo) y mediciones en
[docs/models.md](docs/models.md).

### 4. Iconos y mascota (opcional)

`tools/mascot/` regenera el icono, el splash y las capas de Toco desde las ilustraciones (solo necesita Pillow).
Ver [docs/mascota.md](docs/mascota.md).

## Compilar la release

APK por arquitectura (cada uno lleva solo sus librerías nativas):

```bash
flutter build apk --release --split-per-abi \
  --target-platform android-arm,android-arm64 --build-number <N>
```

Salen en `build/app/outputs/flutter-apk/`:

- `app-arm64-v8a-release.apk` (~20 MB): móviles y tablets de 64 bits (la gran mayoría).
- `app-armeabi-v7a-release.apk` (~17 MB): teléfonos de 32 bits, **sin probar en un dispositivo real**.

Notas:

- **Sube siempre `--build-number`** respecto a la versión instalada, para actualizar sin desinstalar: desinstalar
  borra los perfiles, el historial y las medallas.
- El APK sale **firmado con la clave de depuración**. Sirve para repartirlo a mano; para una tienda hay que crear
  tu propia clave (`android/app/build.gradle.kts`, bloque `signingConfigs`) y guardarla fuera del repositorio.
- Mientras no tenga clave propia, Android pedirá permitir «orígenes desconocidos» al instalar.

## Instalar en un dispositivo y usarlo

1. Instala el APK (`adb install -r app-arm64-v8a-release.apk` o abriéndolo en el teléfono).
2. Crea tu nombre y un PIN de 4 o 6 dígitos.
3. Copia el modelo `.gguf`, `knowledge.db` y los PDF a `Android/data/com.inocencia.app/files/` (los PDF, en la
   subcarpeta `libros/`), o usa la opción **Compartir / Copiar a…** desde otro dispositivo con la app.
4. **Zona de padres → Archivos → Detectar** para vincularlos.
5. Crea los perfiles y deja que el niño entre a **Mi tutor**.

La guía completa, con solución de problemas, está en [docs/guia-padres.md](docs/guia-padres.md).

**Voz en español.** La lectura en voz alta usa el motor de texto a voz de Android. Si el dispositivo solo tiene voz
en inglés, la app lo avisa: hay que instalar los datos de voz en español (Ajustes › Sistema › Idiomas › Salida de
texto a voz › Motor de Google › Instalar datos de voz).

## Estructura del código

Clean Architecture por funcionalidades. Cada carpeta de `lib/features/` suele tener `domain/` (reglas y
contratos, sin Flutter), `data/` (implementaciones), `application/` (controladores Riverpod) y `presentation/`
(pantallas).

```
lib/
├─ main.dart, app.dart          arranque, tema, rutas
├─ core/
│  ├─ di/                       proveedores compartidos (inyección de dependencias)
│  ├─ router/                   rutas go_router y redirecciones por sesión
│  ├─ storage/                  base de datos Drift (perfiles, historial, medallas…)
│  ├─ security/                 hash del PIN (PBKDF2) y bloqueo por intentos
│  ├─ theme/, responsive/       tema normal y de ahorro; adaptación móvil/tablet
│  └─ widgets/                  splash, teclado de PIN, badge sin internet
└─ features/
   ├─ auth/, profiles/, admin/  PIN, perfiles y zona de padres
   ├─ setup/                    primera configuración
   ├─ home/                     inicio del niño
   ├─ tutor/                    chat, prompt, motor llama.cpp (isolate) y RAG
   ├─ knowledge/                acceso a knowledge.db
   ├─ library/                  lector de PDF
   ├─ mascot/                   Toco
   ├─ pomodoro/                 estudio y descanso
   ├─ speech/                   lectura en voz alta
   ├─ quiz/, achievements/      quiz y medallas
   ├─ power/                    modo batería / apagón
   ├─ appearance/, notifications/ ajustes y recordatorios
   └─ external_data/            vincular, compartir y copiar modelo, base y libros
native/llama/                   script para compilar llama.cpp para Android
tools/                          knowledge_builder (libros → base) y mascot (iconos)
docs/                           documentación detallada
test/                           pruebas
```

Estado con **Riverpod**; navegación con **go_router**; persistencia con **Drift** (esquema v3 con migraciones);
preferencias con `shared_preferences`; el PIN y secretos con `flutter_secure_storage`.

## Pruebas

```bash
flutter analyze
flutter test        # ~410 pruebas; necesitan clang (pdfrx compila PDFium)
python3 -m unittest discover -s tools/knowledge_builder   # constructor de la base
```

Los tests cubren el prompt y el chat con un motor falso, la base y sus migraciones, el PIN, el Pomodoro, la voz, el
quiz y sus medallas, el modo batería y los flujos de pantalla. El visor de PDF real y la inferencia real solo se
prueban en un dispositivo físico.

## Privacidad y seguridad

- **Sin red.** La release no declara el permiso `INTERNET` (solo las compilaciones de depuración, para el hot reload); los datos del niño (nombre, historial, medallas, progreso de lectura)
  no salen del dispositivo.
- **PIN.** Se guarda como hash PBKDF2-HMAC-SHA256 con sal aleatoria, y hay bloqueo temporal tras 5 intentos
  fallidos. Es una barrera doméstica para que el niño no entre a la zona de padres, no seguridad fuerte.
- **Permisos usados:** notificaciones y alarmas exactas (recordatorios), arranque del sistema (reprogramarlos) y
  acceso a todos los archivos solo para el explorador de carpetas opcional de Android 11+, porque el modelo y los
  libros pesan gigas.
- **Compartir** (modelo, base, libros) usa el selector del sistema: el usuario elige el destino.

## Rendimiento y límites conocidos

- Un modelo de 3B tarda unos **30-40 s** por respuesta en un teléfono de gama alta, y el móvil se calienta con
  varias preguntas seguidas (los núcleos bajan de frecuencia). El 1.5B es más rápido pero se equivoca más.
- **La calidad del quiz con el 3B es floja**: puede generar preguntas ambiguas. Se filtran, pero conviene que un
  adulto las revise. Mejoraría con el modelo de 7B o con preguntas hechas por plantillas.
- Un modelo de IA pequeño **puede equivocarse**; por eso el tutor cita siempre la página del libro.
- La lectura en voz alta necesita datos de voz en español instalados en el dispositivo.
- La versión de **32 bits** (armeabi-v7a) está sin probar en un teléfono real; un proceso de 32 bits tiene unos
  3 GB de memoria, así que el modelo realista allí es el de 1.5B.
- El APK de release se firma con la clave de depuración.

La lista viva de lo pendiente está en [docs/pendiente.md](docs/pendiente.md).

## Documentación

- [docs/guia-padres.md](docs/guia-padres.md): guía para padres (instalar, copiar modelo y libros, perfiles, problemas).
- [docs/pendiente.md](docs/pendiente.md): estado actual y lo que falta.
- [docs/models.md](docs/models.md): modelos probados y mediciones en un Pixel 6.
- [docs/libros.md](docs/libros.md): cómo dar los libros a la app y lector de PDF.
- [docs/mascota.md](docs/mascota.md): Toco, sus capas y su estado de ánimo.
- [docs/knowledge_db_schema.md](docs/knowledge_db_schema.md): contrato de la base de conocimiento.

## Contribuir

Las ideas y los informes de fallos son bienvenidos (issues). Antes de enviar cambios:

1. `flutter analyze` sin avisos y `flutter test` en verde.
2. Sigue la estructura por funcionalidades y el estilo del código vecino (comentarios en español).
3. No subas libros, modelos ni claves de firma.
4. Las pruebas de lógica no deben usar `Timer`: inyecta el reloj o el temporizador como un proveedor.

## Licencia y créditos

El código de este repositorio se distribuye bajo la **licencia Apache 2.0** (ver [LICENSE](LICENSE) y
[NOTICE](NOTICE)). La licencia cubre el código, no los modelos ni los libros, que tienen sus propios términos.

La app está pensada para **niños menores de edad**: no recoge datos, no tiene cuentas ni anuncios y no usa
internet. Si la distribuyes o la modificas, mantén ese principio y revisa la normativa de protección de menores de
tu país.

Créditos y avisos:

- Modelos **Qwen2.5** (Alibaba Cloud): Apache-2.0 (1.5B y 7B) y licencia Qwen Research (3B). Revisa cada licencia
  antes de redistribuirlos.
- **llama.cpp** (MIT) y **llama_cpp_dart**, **PDFium** (vía `pdfrx`), **Flutter** y demás paquetes de
  [pubspec.yaml](pubspec.yaml), cada uno con su licencia.
- Los **libros de texto** pertenecen a sus autores y editoriales y no forman parte de este repositorio.
- La mascota **Toco** y los versos de la pantalla de bienvenida (`assets/frases/`) tienen su propia autoría:
  comprueba que puedes redistribuirlos antes de publicar.
