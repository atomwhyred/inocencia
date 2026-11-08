# Lo que falta para terminar inocencIA

Estado a 29-oct-2026. Hecho: base, perfiles, PIN y zona de padres; tutor local con RAG; recordatorios (varios,
cada uno con su interruptor); chat con historial por niño; libros PDF con página guardada y carpeta que busca
el padre; mascota Toco; exportar/compartir offline el modelo, la base y los libros; splash con Toco y una frase
al azar. Probado en una **Xiaomi Pad 5** (tablet real): "va muy bien". Lo que queda:

## Cierre del proyecto
- [x] ~~Probar en una tablet real~~ (Xiaomi Pad 5, 28-oct: bien).
- [x] ~~Fase 3~~ (29-oct): grado bajo el nombre en los perfiles; chat sin avatar, Toco arriba al centro y solo el
  icono sin internet a la derecha; tocar a Toco da un gesto (estrellitas) y un mensaje que promete un juego.
- [x] ~~Fase 4~~ (29-oct): Pomodoro infantil (interruptor en Apariencia, activado por defecto; 15+5 min de 1.º a 3.º,
  20+5 de 4.º a 6.º). Probado 15 min reales en el Pixel 6: descanso, cuenta atrás y vuelta con el botón.
  El estudio solo cuenta con el chat abierto y a la vista; el descanso sigue aunque salga del chat.
- [ ] **Voz en español para la lectura en voz alta.** La app usa el motor de voz de Android, sin internet, pero el
  Pixel 6 de pruebas solo tiene datos de voz en inglés (en-US): la app lo detecta y avisa. Cada dispositivo
  necesita instalar una vez la voz en español (Ajustes › Sistema › Idiomas › Salida de texto a voz › Motor de
  Google › Instalar datos de voz › Español), con internet o copiando el paquete. **Sin probar el audio real en
  español**; la lógica (pausa, parar, una a la vez) está probada con una voz falsa.
- [ ] **Calidad de los quizzes con el 3B.** El quiz (botón arriba a la derecha del chat) funciona de punta a punta en el
  Pixel 6, pero el Qwen 3B escribe preguntas flojas: a veces cita "el recuadro de la página 138" o marca como correcta
  una opción sin sentido (se vio "cine" como mayúscula). Se filtran: la respuesta correcta debe salir del texto del
  libro y no se admiten preguntas que dependan de páginas o dibujos. Aun así conviene revisar con un adulto, probar
  con el 7B o generar las preguntas con plantillas a partir del texto del libro. Cada pregunta tarda ~40 s en un 3B.
- [ ] **Modo batería / apagón: falta ver el aviso con batería baja real.** Verificado en el Pixel 6: el interruptor
  del inicio y del chat pone el fondo negro puro, Toco queda quieto y el tutor sigue respondiendo. Falta el aviso
  del 20 % (la simulación con `dumpsys battery` se reinicia sola mientras el USB carga el móvil).
- [ ] **Probar el modelo de 7B en un móvil de 12 GB.** Está descargado (`models/qwen2.5-7b-instruct-q4_k_m.gguf`)
  y en el catálogo, pero **sin medir**: no cabe con margen en el Pixel 6 de 8 GB. Se espera ~2,3× la latencia
  del 3B ([models.md](models.md)).
- [ ] **APK de producción firmado.** Hoy el release se firma con la clave de depuración
  (`android/app/build.gradle.kts`). Hay que crear el keystore y compilar por ABI
  (`flutter build apk --release --split-per-abi`).
- [x] ~~Manual corto para padres~~ (29-oct): [guia-padres.md](guia-padres.md). Falta revisarlo con un padre real
  (feedback de los amigos) y añadir cómo borrar conversaciones.
- [ ] **APK de 32 bits (armeabi-v7a) sin probar en un teléfono real.** Se compila (sin llamafile, que no compila en
  armv7) y arranca la app en el empaquetado, pero no hay un teléfono de 32 bits para medir. Un proceso de 32 bits
  tiene unos 3 GB de espacio de direcciones: lo realista es el modelo de 1.5B.
- [ ] **Copia de seguridad o exportación del historial** (opcional, no se pidió).

## Juego (8-nov)
- [x] ~~Carrera de tocororos / Entre todos~~: en un teléfono y entre teléfonos (Wi-Fi o punto de acceso), cada niño con
  preguntas de su grado. Ver [juego.md](juego.md).
- [ ] **Generar el banco completo** (≈7 h para 50 por grado en el PC) y revisar `build/game_questions.csv`.
- [ ] Probar la partida en red con dos teléfonos de verdad (Pixel 6 + Pad 5) y el descubrimiento de salas por UDP
  en un punto de acceso (en el PC solo se probó con `adb forward`).
- [ ] Banco en inglés: el 3B escribía preguntas sin sentido; habría que hacerlas a mano o con otro método.

## Pulido
- [x] ~~Inicio del niño con barra inferior flotante~~ (8-nov): Toco con "¿Qué aprendemos hoy?" en el centro, resumen de
  medallas y tarjetas y barra centrada (Tutor, Libros, Medallas, Tarjetas y, a la derecha, el perfil del niño con su
  avatar y nombre, que al tocarlo cambia de perfil). Revisado en oscuro, claro y modo batería.
- [ ] **Pulido visual del chat** (burbujas, animaciones), Fase 3.
- [ ] **Ampliar las frases de aprobación de Toco** (`verdictOf` en
  `lib/features/mascot/domain/mascot_mood.dart`) viendo respuestas reales del modelo.
- [ ] **Fotogramas perdidos de Toco**: no se pudieron medir (`dumpsys gfxinfo` no ve el render de Flutter);
  usar el perfilador de Flutter DevTools si el teléfono va justo. El interruptor de Apariencia la apaga.
- [ ] Página del PDF frente a la impresa: el tutor y el lector cuentan páginas del PDF (ver [libros.md](libros.md)).

## Flashcards (30-oct)
- [x] ~~Fase 1: tarjetas offline~~: «Mis tarjetas», repaso «La sabía/A repasar», «Crear tarjetas» desde el chat con el modelo local.
  Probado en el Pixel 6 con el 3B (generar, estudiar, guardar repasos; migración de la base v3→v4 sobre datos reales).
- [ ] **Calidad de las tarjetas con el 3B.** De 4 que escribe, se conservan 1-2 (el filtro descarta las no apoyadas en el libro).
  Las que pasan a veces son correctas pero incompletas («Es un nombre de persona»). Revisar con un adulto; mejorar con el 7B o
  con plantillas a partir del texto. En el registro `[tarjetas]` se ve lo que escribe el modelo y lo descartado.
- Pendiente de futuras fases: repetición espaciada, medallas por tarjetas (ya se guardan los contadores), editar tarjetas a mano.

## Rendimiento en el Xiaomi 17T Pro (Dimensity 9500, 12 GB)
- [ ] **Respuestas de 1-3 min con el 1.5B, sin explicar. Esperando el diagnóstico de la persona en Brasil**
  (Zona de padres → Archivos → Diagnóstico del tutor → Copiar). Un chip así debería ir más rápido que el Pixel 6. La app ya
  escribe un diagnóstico (`adb logcat | grep "\[tutor\]"`): variantes de CPU instaladas, **funciones de CPU que ve
  llama.cpp** (en el Pixel 6: `NEON | ARM_FMA | FP16_VA | DOTPROD | LLAMAFILE | REPACK`), modelo usado, hilos,
  frecuencias de cada núcleo y piezas/s. Falta ejecutarlo en el Xiaomi: si faltan `DOTPROD`/`MATMUL_INT8` se cargó la
  variante base; si el modelo es el 3B o el 7B, es esperable; si va a pocas piezas/s con todo bien, es calor o HyperOS.
- **Causa encontrada (30-oct):** el diagnóstico del 17T Pro mostró que usaba el modelo de **7B**, que la app recomendaba
  a partir de 10 GB de RAM. Ya no se recomienda (solo 3B ≥ 7 GB, 1.5B por debajo) y avisa si está vinculado. Falta que la
  persona repita con el 3B o el 1.5B y envíe el diagnóstico con una respuesta.
- [x] ~~Reducir el tiempo hasta la primera pieza~~ (8-nov): `maxContextChars` 1500 → 1100. Pixel 6 con el 3B: primera
  pieza 22/26/28 s en 3 turnos (antes ~30/30/33 s). Respuestas aún apoyadas en el libro.
- [x] ~~Diagnóstico sin respuesta~~ (8-nov): se anota aunque se corte la respuesta, con tokens y tokens/s del prompt, y se guarda.
- [ ] **Medir en la Pad 5 y el 17T Pro con el APK nuevo** (el 17T Pro usa ahora 8 hilos para el prompt).
- [x] ~~3B en Q4_0~~ (8-nov): ~2× más rápido y calidad parecida; ahora es el recomendado (ver [models.md](models.md)).
- [x] ~~Flash attention~~ (8-nov): sin efecto en el Pixel 6, desactivado. Queda KleidiAI (`-DGGML_CPU_KLEIDIAI=ON`) para el 17T Pro.
- [x] ~~"Dame un ejemplo…" se tomaba como respuesta~~ (8-nov): `dame`, `muestrame`, `enseñame`, `puedes`, `necesito` en `_nonAnswerStarts`.
- [x] ~~El tutor cita lo que el niño no ve~~ (8-nov): el prompt no bastaba; `TutorPrompt.hideUnseen` quita "en la tabla",
  "del ejercicio", "en el poema", "en el ejemplo", "al ver el dibujo", páginas... (respeta "tabla de multiplicar" y "tu libro").
- [ ] Medir Q4_0 en la Pad 5 y el 17T Pro.
- Los hilos ahora salen de los núcleos rápidos (`lib/features/tutor/domain/cpu_threads.dart`), no de «núcleos/2».

## Seguridad (revisión del 29-oct, pendiente de aplicar antes de publicar)
- [x] ~~Desactivar la copia de seguridad de Android~~ (29-oct, `allowBackup="false"`). Antes: añadir `android:allowBackup="false"` en `<application>` de
  `AndroidManifest.xml`. Hoy `adb backup` o la copia en la nube pueden sacar la base con nombres, historial y los
  hashes de PIN (un PIN de 4 dígitos se averigua con 10.000 intentos). Exige recompilar la release.
- [ ] **Firma propia.** El release usa la clave de depuración, que es pública: cualquiera puede firmar una
  «actualización» falsa. Crear un keystore propio, configurarlo en `signingConfigs` y guardarlo fuera del repositorio.
  Cambiar de clave obliga a desinstalar una vez (se pierden los datos de las instalaciones de prueba).
- [ ] **Revisar `MANAGE_EXTERNAL_STORAGE`.** Se usa solo para el explorador de carpetas opcional de Android 11+.
  Valorar quitarlo (basta la carpeta de la app y el selector del sistema) o explicarlo en el README; Google Play lo restringe.
- Sin problema: la release no declara `INTERNET`, la búsqueda en los libros usa consultas con parámetros, los PIN van
  con PBKDF2 + sal y bloqueo tras 5 fallos, y el proveedor de archivos no está exportado. El PIN sigue siendo una
  barrera doméstica (con root o borrando los datos de la app se salta).

## Aparcado a petición del usuario
- Calor del teléfono con el modelo trabajando (la latencia crece por temperatura, no por el historial).
- Calidad del modelo de 3B (pistas y preguntas de seguimiento a veces flojas).

## Recordatorios de desarrollo
- `flutter test` necesita `clang` en el PC (pdfrx compila PDFium); el visor PDF real solo se prueba en el móvil.
- Compilar Android necesita un JDK completo con `javac` (en Fedora 44: `java-25-openjdk-devel`; la 21 ya no está).
  Si Gradle sigue sin verlo, `android/gradlew --stop`.
- `build/knowledge.db` se borra con `flutter clean`: hay copia en `models/knowledge.db`.
- Los tests que pintan el chat deben sobrescribir `mascotAnimateProvider` (a `false`) y `mascotAtlasProvider`.
- Probar siempre en el dispositivo físico por USB (`adb devices` antes).
