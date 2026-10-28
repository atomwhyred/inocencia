# Libros para leer (PDF)

El niño puede leer sus libros y cuadernos desde **Mis libros**, como un libro digital. La app muestra
el **PDF original** (con imágenes, tablas y ejercicios); la base de conocimiento (`knowledge.db`) solo
guarda texto plano para el tutor y no sirve para leer.

## Qué hay que copiar y dónde

Hay dos maneras, y valen las dos a la vez:

1. **Copiarlos a la carpeta de la app**, con su nombre original (`6to_matematica.pdf`), en
   `Android/data/com.inocencia.app/files/libros/` (también tarjeta SD, o directamente `files/` junto al modelo).
   Se detectan solos.
2. **Que el padre busque la carpeta donde ya están** (Descargas, tarjeta SD, `Documentos`...). En
   **Zona de padres → Archivos → "Libros para leer"**:
   - **Detectar** rastrea el almacenamiento (hasta 3 niveles de subcarpetas) y ofrece las carpetas que
     contienen PDF del catálogo, la que más libros tiene primero. Si los libros están repartidos en
     subcarpetas por grado (`Libros/6to/`, `Libros/5to/`), ofrece la carpeta madre.
   - **Buscar carpeta** abre el explorador de rutas: se navega hasta la carpeta y se pulsa
     **"Usar esta carpeta"**. Se usa donde está, sin copiar nada.
   - **Quitar vínculo** la olvida. Los PDF no se borran.

   Fuera de la carpeta de la app, Android 11+ pide el permiso **"Acceso a todos los archivos"** (la misma
   pantalla tiene el botón "Conceder permiso").

- La carpeta vinculada se lee con sus subcarpetas (3 niveles). Si el mismo libro está en varios sitios, gana
  la carpeta vinculada, luego `libros/` de la app y por último la carpeta de la app.
- El nombre del PDF sin `.pdf` es el identificador del libro y se compara sin distinguir mayúsculas
  (`6TO_ESP.pdf` vale para `6to_esp`). La lista de libros sale de `meta.books` de la base de conocimiento.
- **Cada niño ve los libros de su grado.** La carpeta es de todo el teléfono, no de un niño: al añadir un
  niño nuevo, sus libros (según su grado, por fecha de nacimiento o el que fije el padre) aparecen en
  "Mis libros" sin hacer nada más, si los PDF de ese grado están en la carpeta. La tarjeta lo comprueba por
  niño: "Leo (6.º grado): 19 de 21 libros", con aviso si faltan.
- Un libro que falta sale marcado ("No está en este teléfono") y no se puede abrir.
- Tamaños: los 19 libros de 6.º suman ~130 MB; los 49 de todos los grados, ~560 MB.

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
