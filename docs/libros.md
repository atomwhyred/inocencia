# Libros para leer (PDF)

El niño puede leer sus libros y cuadernos desde **Mis libros**, como un libro digital. La app muestra
el **PDF original** (con imágenes, tablas y ejercicios); la base de conocimiento (`knowledge.db`) solo
guarda texto plano para el tutor y no sirve para leer.

## Qué hay que copiar y dónde

- Los PDF se copian al teléfono, **con su nombre original** (`6to_matematica.pdf`), a la carpeta
  `libros/` dentro de la carpeta de la app:
  `Android/data/com.inocencia.app/files/libros/` (también vale tarjeta SD, o directamente la carpeta
  `files/` junto al modelo).
- **No hay que vincularlos**: se detectan solos. La lista de libros sale de `meta.books` de la base de
  conocimiento, filtrada por el grado del niño; el nombre del PDF sin `.pdf` es el identificador del libro.
- **Zona de padres → Archivos → "Libros para leer"** dice cuántos de los libros del catálogo ya están en
  el teléfono y muestra la carpeta exacta. Un libro que falta sale marcado ("No está en este teléfono") y
  no se puede abrir.
- Tamaños: los 19 libros de 6.º suman ~130 MB; los 49 de todos los grados, ~560 MB. Basta copiar los del
  grado de cada niño.

## Página guardada y conversaciones

- Cada niño tiene su propia página en cada libro (tabla `ReadingProgress`), que se guarda al pasar de página
  y sobrevive a cerrar la app. Se abre por donde se quedó.
- Las conversaciones con el tutor se guardan por niño (`TutorMessages`). El padre puede borrarlas desde su
  zona: editar el perfil → "Conversaciones con el tutor". Al eliminar un perfil se borran también su
  conversación y su progreso.

## Las páginas del tutor y las impresas no coinciden

Las fuentes del tutor ("pág. 105") y el lector cuentan **páginas del PDF**, no el número impreso en la
página (los libros llevan cubierta, créditos e índice delante: en `6to_esp`, la página 105 del PDF es la 96
impresa). Tocar una fuente del tutor abre el libro justo en esa página, así que el niño no necesita
traducirlo.

## Para desarrollar

`flutter test` compila `pdfrx` (PDFium) como asset nativo, y para eso necesita un compilador de C en el PC
(`sudo dnf install clang`). PDFium no se puede cargar dentro de los tests de widgets, así que el lector va
detrás de `BookViewerFactory` ([book_viewer.dart](../lib/features/library/presentation/book_viewer.dart)) y
los tests usan un visor falso; el visor real se prueba en un teléfono.
