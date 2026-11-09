# Modelos de IA para inocencIA

La app no trae el modelo: se descarga una vez (con internet), se copia al teléfono y se
vincula en **Zona de padres → Archivos**. La pestaña muestra el modelo recomendado según la RAM.

## Modelos probados (formato GGUF, cuantización Q4_K_M)

| Modelo | Archivo | Tamaño | RAM del teléfono | Notas |
|---|---|---|---|---|
| Qwen2.5-1.5B-Instruct | `qwen2.5-1.5b-instruct-q4_k_m.gguf` | 1,12 GB | cualquiera ≥ 3 GB | ~26 s por respuesta en un Pixel 6. Se equivoca más: llegó a confundir respiración y fotosíntesis. |
| Qwen2.5-3B-Instruct | `qwen2.5-3b-instruct-q4_k_m.gguf` | 2,10 GB | ≥ 7 GB (8 GB anunciados) | ~27 s al primer token y ~32 s en total (hasta ~40 s en turnos de seguimiento). Fiel al libro en las pruebas. |
| Qwen2.5-7B-Instruct | `qwen2.5-7b-instruct-q4_k_m.gguf` | 4,68 GB | ≥ 10 GB informados por Android (12 GB anunciados) | **No recomendado.** En un Xiaomi 17T Pro (Dimensity 9500, 12 GB) tardaba de 1 a 3 minutos por respuesta (una persona lo vinculó siguiendo la recomendación antigua). Que quepa en la RAM no significa que vaya rápido. La app ya no lo recomienda y avisa si está vinculado. |

Descarga: Hugging Face, repositorios `Qwen/Qwen2.5-1.5B-Instruct-GGUF`, `Qwen/Qwen2.5-3B-Instruct-GGUF` y, para el
de 7B, `bartowski/Qwen2.5-7B-Instruct-GGUF` (archivo único `Qwen2.5-7B-Instruct-Q4_K_M.gguf`, 4.683.074.240 bytes;
el repositorio oficial de Qwen lo parte en dos archivos y la app necesita uno solo; se renombra a minúsculas como los
otros). Licencia: Apache-2.0 el de 1,5B y el de 7B; el de 3B usa la licencia Qwen Research: revísala antes de
distribuirlo.

Medidas en un Pixel 6 (8 GB, Tensor, solo CPU). No hay mediciones en otros teléfonos.
La recomendación de RAM del 3B es una estimación: 2,1 GB de modelo + contexto + Android.

### Seguimiento con el 3B (Pixel 6, conversación de 4 turnos desde frío)

La latencia crece con los turnos por **calor**, no por el historial: el prompt casi no cambia
(2471 → 2847 caracteres) pero los núcleos grandes bajan de ~1,45 a ~1,0 GHz y el estado térmico pasa a 1
desde el turno 2. Reducir el historial no lo arregla; solo ayuda calcular menos por turno.

Por eso el mensaje de sistema (~220 de ~750 tokens) se procesa **una sola vez** por sesión y grado
(`LlamaWorker`, isolate propio con `Llama` directo) y cada turno carga ese estado de la caché en vez de
reprocesarlo. Con `LlamaParent` no era posible: su `stop` llegaba decenas de tokens tarde y la caché
guardaba texto inventado tras el prefijo.

| Turno | Primer token antes → ahora | Total antes → ahora |
|---|---|---|
| 1 | 34,1 → 30,1 s | 39,2 → 35,7 s |
| 2 | 41,4 → 30,2 s | 43,3 → 37,9 s |
| 3 | 48,5 → 33,2 s | 54,8 → 41,5 s |
| 4 | 54,5 → 39,5 s | 60,7 → 46,5 s |

El total ya incluye cortar la respuesta tras la primera pregunta (el modelo encadena 2-3). El primer
turno de cada sesión paga además ~8 s para construir el prefijo (8,5 MB de caché).

Cuando el niño contesta, el 3B valora la respuesta y corrige; con "no sé" da una pista. Su límite: las
pistas y preguntas de seguimiento a veces son flojas o demasiado avanzadas para el grado.

La mascota ([mascota.md](mascota.md)) no cambia estos tiempos: con y sin ella el primer token tarda lo mismo
(diferencia < 3 %).

## Dónde copiarlos

`Android/data/com.inocencia.app/files/` (almacenamiento interno o tarjeta SD). No necesita permisos.
Si hay varios `.gguf`, el botón **Detectar** pregunta cuál usar. Esa carpeta se borra al desinstalar la app.

## Libros para leer

Los PDF originales se copian a `libros/` junto al modelo y se detectan solos: ver [libros.md](libros.md).

## Base de libros

`build/knowledge.db` se genera con `tools/knowledge_builder/build_knowledge_db.py` desde `libros/`
(ver `docs/knowledge_db_schema.md`). Se copia a la misma carpeta que el modelo.
Los PDF se nombran `<grado>_<...>.pdf` (`6to_matematica.pdf`, `6to_ct_ciencias.pdf`: `ct` = cuaderno de trabajo).

## Mediciones por diagnóstico (Zona de padres → Archivos → Diagnóstico del tutor)

| Dispositivo | Modelo | Hilos | Primera pieza | Generación |
|---|---|---|---|---|
| Xiaomi Pad 5 (Snapdragon 860, 6 GB) | 3B | 4 de 8 | 24 s | 130 piezas en 42 s (**7,1 piezas/s**) |
| Xiaomi 17T Pro (Dimensity 9500, 12 GB) | 7B | 4 de 8 | sin medir | sin medir (la respuesta tardaba 1-3 min) |
| Xiaomi 17T Pro, 8-nov | 3B Q4_0 | 4 de 8 (8 para el prompt) | 47 s (568 tokens, 12 tokens/s) | 131 piezas en 722 s (**0,2 piezas/s**): anómalo, ver [pendiente.md](pendiente.md) |
| Xiaomi 17T Pro, 9-nov (prueba de velocidad: 3 hilos / 4 para el prompt) | 3B Q4_0 | 3 de 8 (4 para el prompt) | 37 s (805 tokens, 21,8 tokens/s) | 28 piezas en 40 s (**8,2 piezas/s**) |
| Xiaomi 17T Pro, 9-nov | 3B Q4_K_M | 3 de 8 (4) | 42 s (627 tokens, 14,9 tokens/s) | **8,1 piezas/s** |
| Xiaomi 17T Pro, 9-nov | 7B | 3 de 8 (4) | 104 s (739 tokens, 7,1 tokens/s) | **3,3 piezas/s** ("aceptable, pero mejorable") |
| Redmi Note 9 (Helio G85, **3,7 GB**), 9-nov | 1.5B Q4_K_M | 6 de 8 (6 / 8 para el prompt) | 38-41 s (757-845 tokens) | 4,7-5,3 piezas/s |
| Redmi Note 9, 9-nov | 3B Q4_0 | 6 de 8 (8 para el prompt) | **no llega**: la app muere (kill por memoria) unos 6 s después de enviar la pregunta, dos veces | no viable en 3,7 GB (1,2 GB libres; Android mata también otras apps) |
| Pixel 6 (Tensor, 8 GB), 8-nov, libro a 1100 caracteres | 3B | 4 de 8 | 22 / 26 / 28 s (602 / 540 / 566 tokens, ~20-27 tokens/s) | 6,5-7,9 piezas/s |

### Q4_K_M frente a Q4_0 (3B, Pixel 6, 8-nov)

`qwen2.5-3b-instruct-q4_0.gguf` (1,998 GB, repo oficial `Qwen/Qwen2.5-3B-Instruct-GGUF`, SHA-256
`670d82d0…e9816a`). Mismas 3 preguntas desde una conversación vacía, prompts casi iguales (≈500 / 390 / 490 tokens):

| | Primera pieza (turnos 1/2/3) | Prompt | Generación |
|---|---|---|---|
| Q4_K_M | 20 / 17 / 23 s | ~21-25 tokens/s | 6,8-7,4 piezas/s |
| Q4_0 | 9 / 7 / 11 s | ~45-56 tokens/s | 7,9-8,9 piezas/s |

Q4_0 procesa el prompt **unas 2,2 veces más rápido**: llama.cpp reempaqueta Q4_0 para dotprod (`REPACK`) y
Q4_K no en chips sin i8mm. Repetido en 4 tandas alternas (K_M, 0, K_M, 0): Q4_K_M 19-25 s y Q4_0 8-11 s.

**Calidad (8 preguntas de 4.º, conversación nueva, 8-nov):** parecida. Los dos aciertan multiplicación,
plural de "lápiz" (lápices), raíces, verbo, sustantivo propio y adjetivo; "suma con llevadas" no está en los
libros de 4.º. Q4_K_M: fracción mejor explicada. Q4_0: fracción confusa ("dividida por otro número") y una
pregunta avanzada ("la distributiva"). **Los dos** siguen citando lo que el niño no ve ("la tabla", "el
ejercicio", "el texto") aunque el prompt lo prohíbe. Desde el 8-nov la app **recomienda el 3B en Q4_0**
(`qwen2.5-3b-instruct-q4_0.gguf`); el Q4_K_M se sigue reconociendo como el mismo modelo.

Flash attention (`ContextParams.flashAttention = enabled`) no cambió nada en el Pixel 6 (11-12 s / 9 s frente
a 12 s / 8 s): queda desactivado.

Hasta el 8-nov el diagnóstico casi nunca anotaba la respuesta: el tutor la corta tras la primera pregunta del
modelo y el stream se cancelaba sin llegar a `onDone`. Ahora se anota también al cortar, guarda los tokens del
prompt y su velocidad, y sobrevive a cerrar la app. Desde la misma fecha el prompt usa más hilos que la generación
en chips con núcleos medianos fuertes (≥ 2,2 GHz): 8 en el Dimensity 9500; 4 en la Pad 5 y el Pixel 6.

Desde el 8-nov el prompt deja siempre 2 núcleos libres (en el Dimensity 9500 usa 6, no 8). Además, la **prueba de
velocidad** (Zona de padres → Archivos → Diagnóstico) mide cada combinación de hilos en el propio teléfono y guarda la
mejor, y **CPU en modo compatible** evita la variante SVE/SME. Pixel 6, prueba con 2 pasadas: al escribir, 9,5 / 8,7 /
9,2 / 6,6 / 6,1 tokens/s con 2-6 hilos; al leer, 40,6 / 30,0 / 34,2 tokens/s con 4/6/8 hilos. Con 4 o más hilos para
escribir no gana nada: la generación está limitada por la memoria.

**Causa del 0,2 piezas/s del 17T Pro (9-nov):** las dos pruebas de velocidad que llegaron (una con el Q4_0 y otra
guardada, que salió igual en los informes del Q4_K_M y del 7B porque no anotaba el modelo) dicen lo mismo al escribir: 2 hilos 6,9-9,0, **3 hilos 9,8-12,7** y **4, 5 o 6 hilos 0,2 tokens/s**. Los hilos automáticos eran
4 (todos los núcleos rápidos). El Dimensity 9500 no tiene núcleos pequeños que absorban la interfaz y Android: desde el
9-nov, en chips así (todos los núcleos ≥ 2,2 GHz) se deja un núcleo rápido libre al escribir (3) y el prompt usa uno más
(4; con 6 iba igual y con 8 peor). Aun así el prompt del Q4_0 va a ~20 tokens/s, menos de la mitad que en el Pixel 6:
falta probar el **modo compatible** (sin SVE/SME). En la Pad 5 el cuello de botella es el tiempo
hasta la primera pieza (procesar el prompt), no la generación.
