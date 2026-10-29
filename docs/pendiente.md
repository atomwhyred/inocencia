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
- [ ] **Modo batería / apagón: falta verlo en el teléfono.** Código y tests listos (tema negro puro, Toco y puntos
  quietos, tutor con 2 hilos y respuestas de 160 tokens, icono de batería arriba, aviso al bajar del 20 % sin
  cargador). En el Pixel 6 solo se comprobó que la app lee bien la batería (nivel, estado y ahorro del sistema). Falta
  ver el fondo negro, la recarga del modelo y el aviso con batería baja real (la simulación con `dumpsys battery`
  se reinicia sola mientras el USB carga el móvil).
- [ ] **Probar el modelo de 7B en un móvil de 12 GB.** Está descargado (`models/qwen2.5-7b-instruct-q4_k_m.gguf`)
  y en el catálogo, pero **sin medir**: no cabe con margen en el Pixel 6 de 8 GB. Se espera ~2,3× la latencia
  del 3B ([models.md](models.md)).
- [ ] **APK de producción firmado.** Hoy el release se firma con la clave de depuración
  (`android/app/build.gradle.kts`). Hay que crear el keystore y compilar por ABI
  (`flutter build apk --release --split-per-abi`).
- [ ] **Manual corto para padres**: copiar modelo, `knowledge.db` y PDF; vincular carpetas; borrar
  conversaciones; apagar la mascota.
- [ ] **Copia de seguridad o exportación del historial** (opcional, no se pidió).

## Pulido
- [ ] **Pulido visual del chat** (burbujas, animaciones), Fase 3.
- [ ] **Ampliar las frases de aprobación de Toco** (`verdictOf` en
  `lib/features/mascot/domain/mascot_mood.dart`) viendo respuestas reales del modelo.
- [ ] **Fotogramas perdidos de Toco**: no se pudieron medir (`dumpsys gfxinfo` no ve el render de Flutter);
  usar el perfilador de Flutter DevTools si el teléfono va justo. El interruptor de Apariencia la apaga.
- [ ] Página del PDF frente a la impresa: el tutor y el lector cuentan páginas del PDF (ver [libros.md](libros.md)).

## Aparcado a petición del usuario
- Calor del teléfono con el modelo trabajando (la latencia crece por temperatura, no por el historial).
- Calidad del modelo de 3B (pistas y preguntas de seguimiento a veces flojas).

## Recordatorios de desarrollo
- `flutter test` necesita `clang` en el PC (pdfrx compila PDFium); el visor PDF real solo se prueba en el móvil.
- Los tests que pintan el chat deben sobrescribir `mascotAnimateProvider` (a `false`) y `mascotAtlasProvider`.
- Probar siempre en el dispositivo físico por USB (`adb devices` antes).
