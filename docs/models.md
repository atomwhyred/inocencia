# Modelos de IA para inocencIA

La app no trae el modelo: se descarga una vez (con internet), se copia al teléfono y se
vincula en **Zona de padres → Archivos**. La pestaña muestra el modelo recomendado según la RAM.

## Modelos probados (formato GGUF, cuantización Q4_K_M)

| Modelo | Archivo | Tamaño | RAM del teléfono | Notas |
|---|---|---|---|---|
| Qwen2.5-1.5B-Instruct | `qwen2.5-1.5b-instruct-q4_k_m.gguf` | 1,12 GB | cualquiera ≥ 3 GB | ~26 s por respuesta en un Pixel 6. Se equivoca más: llegó a confundir respiración y fotosíntesis. |
| Qwen2.5-3B-Instruct | `qwen2.5-3b-instruct-q4_k_m.gguf` | 2,10 GB | ≥ 7 GB (8 GB anunciados) | ~27 s al primer token y ~32 s en total (hasta ~40 s en turnos de seguimiento). Fiel al libro en las pruebas. |

Descarga: Hugging Face, repositorios `Qwen/Qwen2.5-1.5B-Instruct-GGUF` y `Qwen/Qwen2.5-3B-Instruct-GGUF`
(licencia Apache-2.0 el de 1,5B; el de 3B usa la licencia Qwen Research: revísala antes de distribuirlo).

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

## Dónde copiarlos

`Android/data/com.inocencia.app/files/` (almacenamiento interno o tarjeta SD). No necesita permisos.
Si hay varios `.gguf`, el botón **Detectar** pregunta cuál usar. Esa carpeta se borra al desinstalar la app.

## Base de libros

`build/knowledge.db` se genera con `tools/knowledge_builder/build_knowledge_db.py` desde `libros/`
(ver `docs/knowledge_db_schema.md`). Se copia a la misma carpeta que el modelo.
Los PDF se nombran `<grado>_<...>.pdf` (`6to_matematica.pdf`, `6to_ct_ciencias.pdf`: `ct` = cuaderno de trabajo).
