# Toco, la mascota

Toco es un tocororo (ave nacional de Cuba, de colores azul, rojo y blanco como la app) que acompaña al niño
en el chat del tutor. Es la ilustración del autor ([mascota/](../mascota/)), recortada y animada por capas en
Flutter: **sin 3D, sin WebView, sin dependencias nuevas ni permiso de internet**. Pesa ~380 KB en el APK.

## Qué hace

Dos ejes, calculados con una función pura sobre el estado del chat
([mascot_mood.dart](../lib/features/mascot/domain/mascot_mood.dart)):

| Actividad | Cuándo | Cómo se ve |
|---|---|---|
| `sleeping` | el modelo se está cargando | ojos cerrados, "Z z" |
| `idle` | listo (si no hay mensajes, saluda) | respira, parpadea, mira alrededor |
| `thinking` | el modelo piensa (antes de la primera palabra, ~30 s) | mira arriba, burbuja con puntos |
| `talking` | llega el texto | cabecea, notas musicales |
| `listening` | el niño toca la pregunta del tutor para contestarla | inclina la cabeza, ondas |
| `sad` | sin archivos, error o sin resultados en los libros | cabeza baja, una lágrima suave |

La **emoción** solo aparece cuando el niño *contestó* (no preguntó): `happy` (aletea, estrellitas) si la
primera frase del tutor es positiva ("¡Muy bien!", "Correcto", "Exacto"…) y `concerned` (gesto de ánimo, un
"?") si empieza con "Casi…", "No exactamente…", etc. (`verdictOf`). En la duda no hay emoción. El prompt ya pide
al modelo empezar con "Casi" cuando el niño falla; lo positivo depende de lo que escriba el modelo, así que la
lista de frases está en `mascot_mood.dart` y se puede ampliar mirando respuestas reales.

## Dónde sale

- **Grande** (150-230 dp) al saludar, mientras se carga el modelo y mientras el modelo piensa.
- **Pequeña** (60 dp) junto al nombre del niño el resto del tiempo, y siempre con el teclado abierto o en
  pantallas bajas.
- El padre la apaga en **Zona de padres → Apariencia → "Mostrar la mascota"** (útil si el teléfono va lento o
  se calienta). Sin mascota el chat funciona igual.

## Rendimiento

Se midió en un Pixel 6 con el Qwen2.5-3B, mismas tres preguntas desde frío, con y sin mascota (primer token
incluyendo ~8 s del prefijo en el turno 1):

| Turno | Con Toco | Sin Toco |
|---|---|---|
| 1 | 37,9 s | 38,8 s |
| 2 | 29,8 s | 29,1 s |
| 3 | 30,9 s | 30,5 s |

Diferencia dentro del ruido (< 3 %): dibujar a ~30 fps no alarga la espera. Un solo `Ticker`, sin `setState`
por fotograma, y se detiene si la app pasa a segundo plano (el modelo sigue pensando gracias al servicio en primer plano, pero
Toco no se anima) o Android tiene quitadas las animaciones. Los
fotogramas perdidos no se midieron (`dumpsys gfxinfo` no ve el render de Flutter).

## Cómo está hecho

- **Arte** ([assets/mascot/](../assets/mascot/)): 6 PNG (cola, cuerpo, ala, rama, cabeza, pupila) y
  `layers.json` con offsets, pivotes de giro, ojo y anclas. Se regeneran con
  `python3 tools/mascot/build_layers.py` (solo Pillow) desde `mascota/*.jpg`; `tools/mascot/preview_pose.py`
  compone poses y una hoja de contacto para revisar costuras. El pico está cerrado en el dibujo: "hablar" se
  muestra con cabeceo y notas, no abriendo el pico.
- **Código** ([lib/features/mascot/](../lib/features/mascot/)): `MascotAtlas` carga las capas;
  `poseFor` (pura) da giros, mirada y adornos; `MascotPainter` las dibuja con `FilterQuality.medium`;
  `MascotView` lleva el reloj. Si las capas no cargan, se dibuja un pájaro vectorial sencillo.
- **Tests**: el estado y la valoración (`mascot_mood_test.dart`), la pose (`mascot_pose_test.dart`), la vista y
  el chat (`mascot_view_test.dart`, `tutor_test.dart`). Los tests que pintan el chat deben sobrescribir
  `mascotAnimateProvider` a `false` (una animación infinita colgaría `pumpAndSettle`) y `mascotAtlasProvider`
  para no leer el disco.
- **Ver cada estado sin móvil**: `MASCOT_RENDER_DIR=/ruta flutter test test/tool/render_mascot_test.dart`
  escribe un PNG de cada estado, en claro y oscuro, grande y pequeño.
