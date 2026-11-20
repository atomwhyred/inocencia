# Lo que falta para terminar inocencIA

Estado a 29-oct-2026 (actualizado el 9-nov). Hecho: base, perfiles, PIN y zona de padres; tutor local con RAG; recordatorios (varios,
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
- [x] ~~Aviso de poca batería al lado de los botones~~ (9-nov, feedback del 17T Pro): ahora lo dice Toco, en su globo del
  inicio o como mensaje del tutor en el chat, con los botones debajo. El inicio ya no se desplaza: Toco crece o encoge con
  el alto libre (solo en pantallas muy bajas o con letra muy grande vuelve a desplazarse). La etiqueta "Sin internet" se
  recorta en barras estrechas en vez de desbordarse.
- [ ] **Modo batería / apagón: falta ver el aviso con batería baja real.** `dumpsys battery set level/status` no sirve:
  `battery_plus` lee la propiedad del hardware (`BATTERY_PROPERTY_CAPACITY`/`STATUS`), no la difusión que cambia dumpsys.
  Hay que dejar bajar la batería de verdad, sin cable (o depurar por Wi-Fi con `adb tcpip`). Verificado en el Pixel 6: el interruptor
  del inicio y del chat pone el fondo negro puro, Toco queda quieto y el tutor sigue respondiendo. Falta el aviso
  del 20 % (la simulación con `dumpsys battery` se reinicia sola mientras el USB carga el móvil).
- [x] ~~Probar en un móvil de gama baja~~ (9-nov, **Redmi Note 9**, 3,7 GB, Helio G85 8 núcleos): app, 1.5B Q4_K_M, base
  con el banco y 49 PDF copiados por `adb`; la app lo recomienda sola. Tutor: 757 tokens de prompt, primera pieza 38 s y
  5,3 piezas/s (6 hilos), respuesta apoyada en 3 páginas de 2.º. Aceptable, no rápido.
  - **El 3B Q4_0 no es viable ahí** (9-nov): carga, pero al enviar la pregunta Android mata la app a los ~6 s (dos
    intentos, decenas de `lowmemorykiller`). Con 3,7 GB de RAM el límite es el 1.5B, como ya recomienda la app
    (3B solo desde 7 GB). El Redmi se queda con el 1.5B.
- [ ] **Probar el modelo de 7B en un móvil de 12 GB.** Está descargado (`models/qwen2.5-7b-instruct-q4_k_m.gguf`)
  y en el catálogo, pero **sin medir**: no cabe con margen en el Pixel 6 de 8 GB. Se espera ~2,3× la latencia
  del 3B ([models.md](models.md)).
- [ ] **APK de producción firmado.** Hoy el release se firma con la clave de depuración
  (`android/app/build.gradle.kts`). Hay que crear el keystore y compilar por ABI
  (`flutter build apk --release --split-per-abi`).
- [x] ~~Guías para compartir en Telegram~~ (9-nov): [guias/](guias/README.md), 6 guías cortas.
- [x] ~~Manual corto para padres~~ (29-oct): [guia-padres.md](guia-padres.md). Falta revisarlo con un padre real
  (feedback de los amigos) y añadir cómo borrar conversaciones.
- [ ] **APK de 32 bits (armeabi-v7a) sin probar en un teléfono real.** Se compila (sin llamafile, que no compila en
  armv7) y arranca la app en el empaquetado, pero no hay un teléfono de 32 bits para medir. Un proceso de 32 bits
  tiene unos 3 GB de espacio de direcciones: lo realista es el modelo de 1.5B.
- [ ] **Copia de seguridad o exportación del historial** (opcional, no se pidió).

## Juego (8-nov)
- [x] ~~Carrera de tocororos / Entre todos~~: en un teléfono y entre teléfonos (Wi-Fi o punto de acceso), cada niño con
  preguntas de su grado. Ver [juego.md](juego.md).
- [x] ~~Generar el banco completo~~ (9-nov): 300 preguntas (50 por grado, de 1.º a 6.º) con el 3B Q4_0, ~50 s por
  fragmento, desde una terminal con `./tools/question_bank/generar_banco.sh` (ver [juego.md](juego.md)). CSV revisado,
  copiado a `models/knowledge.db` y al Pixel 6: la carrera saca preguntas del grado del niño con las opciones barajadas.
- [x] ~~Probar la partida en red con dos teléfonos de verdad~~ (9-nov, Pixel 6 + Redmi Note 9, Wi-Fi de casa): el
  descubrimiento por UDP funciona en los dos sentidos (sala visible sin escribir la IP), se unen, cada uno recibe
  preguntas de su grado (4.º y 2.º) y la ronda avanza a la vez en ambos. Sin probar aún: punto de acceso del
  teléfono, 3+ jugadores, y terminar una partida entera.
  - Si en un móvil falla hasta *crear* la sala (`Failed to create server socket ... errno = 111`), Android le está
    bloqueando la red a la app (`dumpsys netpolicy`: `REJECT_ALL` / `Restricted networking mode: true`). Pasaba en el
    Pixel 6 con `settings global restricted_networking_mode=1`; no es un fallo de la app.
  - [x] ~~Fallo al salir de la pantalla de juego en red~~ (9-nov): `LanGameController._shutdown` leía el `Ref` ya
    desechado y lanzaba una excepción; ahora recibe la plataforma guardada en `build()`. Prueba de regresión en
    `test/lan_game_test.dart` (falla sin el arreglo) y comprobado en el Redmi (0 errores al salir).
  - [x] ~~Lista de libros sin refrescar tras vincular la base~~ (9-nov): `_store` en `files_section.dart` invalida
    `libraryStatusProvider` y `childBooksProvider`. Comprobado en el Redmi (desvincular y detectar la base).
  - Al copiar los PDF con `adb` a una carpeta `libros/` nueva, dale permisos (`chmod 777 .../files/libros`): creada por
    `adb shell` queda `drwxrws---` con dueño `shell` y la app ve «0 de 49 libros» aunque estén copiados.
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
- **Diagnóstico del 8-nov con el 3B Q4_0:** primera pieza a los 47 s (568 tokens, 12 tokens/s) y **0,2 piezas/s**
  (131 piezas en 722 s), unas 40 veces más lento que el Pixel 6. Con el 7B iba mejor, así que no es el modelo.
  Sospechas: la app en segundo plano mientras respondía (HyperOS la frena), los 8 hilos del prompt (todos los núcleos),
  calor, o las rutas SVE/SME de la variante `armv9.2`.
- [x] ~~Herramientas para averiguarlo a distancia~~ (8-nov):
  - el diagnóstico anota si la app salió de la pantalla y el estado térmico de Android;
  - el prompt deja siempre 2 núcleos libres (6 en el Dimensity 9500);
  - **prueba de velocidad** en el diagnóstico (2 pasadas, de 2 a 6 hilos al escribir y 4/6/8 al leer), que guarda la
    mejor combinación para ese teléfono;
  - **CPU en modo compatible**, que carga `android_armv8.6_1` (NEON + i8mm, sin SVE/SME) al reiniciar la app.
  - En el Pixel 6 la prueba dura ~1,5 min. Mide 9,5 / 8,7 / 9,2 / 6,6 / 6,1 tokens/s al escribir (2-6 hilos) y
    40 / 30 / 34 tokens/s al leer (4/6/8): elige 2 y 4. Como el Pixel no tiene i8mm, el modo compatible cae a `armv8.2_2`.
- [x] ~~Pedir a la persona del 17T Pro la prueba de velocidad~~ (9-nov): **causa encontrada**. Al escribir, 3 hilos van a
  9,8-12,7 tokens/s y 4, 5 o 6 hilos a **0,2**; los automáticos eran 4. Ahora, en chips sin núcleos pequeños (todos ≥ 2,2 GHz)
  se deja un núcleo rápido libre: 3 al escribir y 4 para el prompt (`CpuThreads`). Con la prueba aplicada: 3B Q4_0 37 s
  hasta la primera pieza y 8,2 piezas/s; 3B Q4_K_M 42 s y 8,1; 7B 104 s y 3,3 ("aceptable, pero mejorable"). Ver
  [models.md](models.md).
- [x] ~~La prueba de velocidad no decía con qué modelo se hizo~~ (9-nov): se guarda el modelo y el informe avisa si ahora es otro.
- [x] ~~La valoración llamaba "muy lento" a todo 7B y "teléfono modesto" al 17T Pro~~ (9-nov): se valora por la velocidad
  medida y, en chips con SME sin modo compatible, sugiere probarlo.
- [ ] **Modo compatible en el 17T Pro**: el prompt del Q4_0 va a ~20 tokens/s (el Pixel 6, 45-56) y 4+ hilos se hunden a 0,2.
  Pedir: activar CPU en modo compatible, cerrar la app, repetir la prueba con el 3B Q4_0 y enviar el diagnóstico. Si mejora,
  usarlo por defecto en chips con SME; si no, probar KleidiAI.
- [ ] Pedir al 17T Pro que pruebe el APK nuevo con **Volver a automático**: el diagnóstico debe decir 3 hilos (4 para el prompt).
- [ ] La respuesta real del 7B va a 3,3 piezas/s y la prueba a ~9,8: contexto más largo o la interfaz compitiendo por los núcleos.
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
- Sin problema: la release declara `INTERNET` solo para el juego en red (nunca sale a internet), la búsqueda en los libros usa consultas con parámetros, los PIN van
  con PBKDF2 + sal y bloqueo tras 5 fallos, y el proveedor de archivos no está exportado. El PIN sigue siendo una
  barrera doméstica (con root o borrando los datos de la app se salta).

## Respuestas con la app en segundo plano (20-nov)
- [x] Servicio en primer plano (`TutorWorkService.kt`, tipo `specialUse`) + wake lock parcial mientras el modelo
  carga o genera (tutor, tarjetas, quiz). Medido con build 2003:
  - Redmi Note 9 (Android 16), 1.5B, Inicio nada más enviar: **antes** el sistema mataba el proceso al instante
    (`am_proc_died`, adj 700) y la respuesta se perdía; **ahora** adj 50 (`fg-service`), 35 s en total
    (7,3 piezas/s), igual que en pantalla.
  - Pixel 6 (Android 16), pantalla apagada: 36 s, wake lock tomado y liberado, aviso "¡Toco ya terminó!".
  - Cerrar desde Recientes a mitad: servicio, aviso y wake lock fuera; la respuesta se pierde (esperado).
- [ ] Probar en un Xiaomi con HyperOS de fábrica (el Redmi de pruebas lleva otra ROM) y en Android 10-12.

- [x] Juego en red: código de sala de 4 cifras, aviso sin el nombre del niño, entradas limitadas (líneas, nombres,
  avatares sin rutas locales, conexiones, un saludo por conexión) y foto solo si el padre lo activa.
- [x] Marcadores de chat (`<|im_start|>`...) neutralizados en libro, niño e historial; campo del tutor a 500 caracteres.
- [x] `knowledge.db` abierta con `trusted_schema=OFF` y `query_only`; el validador exige tablas reales.
- [x] Lista de archivos oficiales (SHA-256) en Zona de padres → Archivos.
- [x] Bloqueo del PIN medido también desde el encendido; PIN obvios rechazados al crearlos; zona de padres cerrada
  al ocultarse la app y tras 10 min sin tocarla.
- [x] Aviso diario privado en la pantalla de bloqueo; `dataExtractionRules`; fotos borradas con el perfil;
  `shareFiles` nunca comparte los datos privados de la app.
- [ ] Actualizar llama.cpp (fijado el 28-dic-2025) y repetir la prueba de velocidad.
- [ ] Mover las consultas a la base de libros fuera del hilo de la interfaz (una base enorme o manipulada congela
  la pantalla mientras se lee).

## Más adelante
- [ ] Versiones para Windows 10/11 y Linux (.deb, .rpm): solo si hay aceptación en Android. Notas y pasos en [otras-plataformas.md](otras-plataformas.md).

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
