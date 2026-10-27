# Contrato de la base de conocimiento (`.db`)

inocencIA no incluye los libros de texto: se transfieren al teléfono como un archivo SQLite
y el padre/madre lo vincula desde **Zona de padres → Archivos**. La app lo abre en **solo lectura**.

Versión del esquema soportada: **`1`**.

## Tablas obligatorias

```sql
CREATE TABLE meta (
  key   TEXT PRIMARY KEY,
  value TEXT
);
-- Filas mínimas: ('schema_version', '1'). Recomendadas: ('built_with', '...'), ('built_at', '...').

CREATE TABLE chunks (
  id      INTEGER PRIMARY KEY,
  grade   INTEGER NOT NULL,   -- 0 = preescolar, 1..12
  subject TEXT    NOT NULL,   -- asignatura, p. ej. 'Matematica'
  book    TEXT,               -- libro de texto de origen
  chapter TEXT,
  page    INTEGER,
  text    TEXT    NOT NULL    -- fragmento de conocimiento (unos cientos de caracteres)
);

CREATE VIRTUAL TABLE chunks_fts USING fts5(
  text,
  content='chunks',
  content_rowid='id',
  tokenize='unicode61 remove_diacritics 2'   -- ojo: la opción se llama `tokenize`, no `tokenizer`
);
INSERT INTO chunks_fts(rowid, text) SELECT id, text FROM chunks;
```

`remove_diacritics 2` hace que «fracción» y «fraccion» coincidan (los niños escriben sin tildes).

## Consulta de recuperación (Módulo 2)

El filtro por grado y asignatura es **estricto**: nunca se devuelven fragmentos de otro grado.

```sql
SELECT c.subject, c.book, c.chapter, c.page, c.text
FROM chunks_fts f
JOIN chunks c ON c.id = f.rowid
WHERE chunks_fts MATCH ?        -- términos de la pregunta
  AND c.grade = ?               -- grado del perfil activo
  AND (? IS NULL OR c.subject = ?)
ORDER BY bm25(chunks_fts)
LIMIT 5;
```

## Validación en la app

Al vincular y en cada arranque se comprueba: existe y se puede leer, es SQLite, tiene `meta`,
`chunks` y `chunks_fts`, y `schema_version` es `1`. Además se muestran el número de
fragmentos, los grados y las asignaturas que contiene.

Referencia de pruebas: `test/external_file_validator_test.dart`.
