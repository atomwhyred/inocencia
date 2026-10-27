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

## Dónde copiarlos

`Android/data/com.inocencia.app/files/` (almacenamiento interno o tarjeta SD). No necesita permisos.
Si hay varios `.gguf`, el botón **Detectar** pregunta cuál usar. Esa carpeta se borra al desinstalar la app.

## Base de libros

`build/knowledge.db` se genera con `tools/knowledge_builder/build_knowledge_db.py` desde `libros/`
(ver `docs/knowledge_db_schema.md`). Se copia a la misma carpeta que el modelo.
Los PDF se nombran `<grado>_<...>.pdf` (`6to_matematica.pdf`, `6to_ct_ciencias.pdf`: `ct` = cuaderno de trabajo).
