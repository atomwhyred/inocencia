# Lo que falta para terminar inocencIA

Estado a 29-oct-2026. Hecho: base, perfiles, PIN y zona de padres; tutor local con RAG; recordatorios (varios,
cada uno con su interruptor); chat con historial por niño; libros PDF con página guardada y carpeta que busca
el padre; mascota Toco; exportar/compartir offline el modelo, la base y los libros; splash con Toco y una frase
al azar. Probado en una **Xiaomi Pad 5** (tablet real): "va muy bien". Lo que queda:

## Cierre del proyecto
- [x] ~~Probar en una tablet real~~ (Xiaomi Pad 5, 28-oct: bien).
- [ ] **Fases 3 y 4 de la lista de mejoras del usuario** (pendientes de confirmar): grado bajo el nombre en los
  perfiles; chat sin avatar, mascota al centro y solo el icono sin internet a la derecha; tocar a Toco para un
  gesto y un mensaje motivador; temporizador Pomodoro infantil (15+5 min de 1.º a 3.º, 20+5 de 4.º a 6.º, con
  interruptor en el panel de padres, activado por defecto).
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
