#!/usr/bin/env python3
"""Construye el knowledge.db de inocencIA a partir de PDF de libros de texto.

Uso:
    python3 tools/knowledge_builder/build_knowledge_db.py \
        --books libros --out build/knowledge.db

Por cada PDF:
  1. extrae el texto de cada pagina con `pdftotext`;
  2. las paginas sin texto (libros escaneados) se pasan por OCR con `tesseract`
     (en paralelo y con cache: relanzar el script no repite el OCR);
  3. limpia el texto, lo trocea en fragmentos de ~700 caracteres y los guarda
     con su grado, asignatura, libro, capitulo y pagina.

El grado y la asignatura salen del nombre del archivo (`6to_ciencias_naturales.pdf`,
`1ro_2do_ca_el_mundo.pdf`): conserva esa convencion al anadir libros.
El formato del .db esta descrito en docs/knowledge_db_schema.md.

Requiere: pdftotext, pdftoppm (poppler) y tesseract con los idiomas spa y eng.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import hashlib
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

SCHEMA_VERSION = "1"
BUILDER_NAME = "inocencia-knowledge-builder 1"

MIN_PAGE_CHARS = 40  # menos caracteres que esto = pagina sin texto -> OCR
TARGET_CHARS = 700
MAX_CHARS = 1000
MIN_CHUNK_CHARS = 60
MIN_LETTER_RATIO = 0.45
MIN_WORDS = 8

# ---------------------------------------------------------------------------
# Nombre de archivo -> grados, asignatura y tipo
# ---------------------------------------------------------------------------

_ORDINAL = re.compile(r"^(\d{1,2})(?:ro|do|er|to|mo|vo|no)$")

_SUBJECT_RULES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"matematica"), "Matemática"),
    (re.compile(r"ortografia|(^|_)esp(_|$)|espanol|lengua"), "Español"),
    (re.compile(r"english|ingles|new_roads"), "Inglés"),
    # "5to_ciencias", "6to_ct_ciencias", "6to_ciencias_naturales_2"...
    (re.compile(r"ciencias"), "Ciencias Naturales"),
    (re.compile(r"mundo[-_]digital"), "Mundo Digital"),
    (re.compile(r"el_mundo"), "El mundo en que vivimos"),
    (re.compile(r"historia"), "Historia de Cuba"),
    (re.compile(r"geografia"), "Geografía"),
    (re.compile(r"civica"), "Educación Cívica"),
    (re.compile(r"laboral"), "Educación Laboral"),
]

_ENGLISH = re.compile(r"english|ingles|new_roads")


@dataclass(frozen=True)
class BookInfo:
    stem: str
    grades: tuple[int, ...]
    subject: str | None
    kind: str  # "Libro" | "Cuaderno"
    ocr_lang: str


def parse_filename(stem: str) -> BookInfo:
    """`6to_ciencias_naturales` -> grado 6, asignatura "Ciencias Naturales"."""
    tokens = stem.lower().split("_")
    grades: list[int] = []
    while tokens and (m := _ORDINAL.match(tokens[0])):
        grades.append(int(m.group(1)))
        tokens.pop(0)
    rest = "_".join(tokens)
    subject = next((name for rx, name in _SUBJECT_RULES if rx.search(rest)), None)
    is_workbook = bool(
        re.search(r"(^|_)ct(_|$)|cuaderno|workbook|videoclases", rest)
    )
    lang = "eng+spa" if _ENGLISH.search(rest) else "spa"
    return BookInfo(
        stem=stem,
        grades=tuple(grades),
        subject=subject,
        kind="Cuaderno" if is_workbook else "Libro",
        ocr_lang=lang,
    )


# ---------------------------------------------------------------------------
# Limpieza y troceado
# ---------------------------------------------------------------------------

_JUNK_LINES = [
    re.compile(r"^\s*\d{1,3}\s*$"),  # numero de pagina suelto
    re.compile(r"^\s*p[aá]gina\s*\w*\s*$", re.I),
    re.compile(r"\b\d{1,2}[-/][A-Za-z]{3}[-/]\d{2}\b.*\b\d{1,2}:\d{2}\b"),  # marca de imprenta
    re.compile(r"^\s*\d{1,2}/\d{1,2}/\d{2,4}\s*$"),
    re.compile(r"^\s*\d{1,2}:\d{2}(\s*[AP]M)?\s*$", re.I),
    re.compile(r"^\s*[A-Z0-9]{1,3}-\d{1,3}\s*$"),  # "6A-14"
]
# Marca de imprenta pegada al texto (el OCR no separa las lineas): "6A-14 1/3/07 10:34 Página 1"
_INLINE_JUNK = re.compile(
    r"\b\w{1,4}-\d{1,3}\s+\d{1,2}/\d{1,2}/\d{2,4}\s+\d{1,2}:\d{2}(?:\s*[AP]M)?\s+P[aá]gina\s+\w+",
    re.I,
)
_CHAPTER = re.compile(
    r"^\s*((?:cap[ií]tulo|unidad|tema|lecci[oó]n)\s+[\dIVXLivxl]+\b.*)$", re.I
)
_SENTENCE_SPLIT = re.compile(r"(?<=[.!?…:])\s+(?=[A-ZÁÉÍÓÚÑ¿¡0-9])")


def clean_page(text: str) -> str:
    """Quita ruido de maquetacion y deja parrafos separados por una linea vacia."""
    text = text.replace("\r", "").replace("­", "")
    text = _INLINE_JUNK.sub("", text)
    # palabras partidas por un guion al final de linea: "informa-\nción"
    text = re.sub(r"(?<=[a-záéíóúñü])-\n(?=[a-záéíóúñü])", "", text)
    lines = [
        ln for ln in text.split("\n") if not any(rx.search(ln) for rx in _JUNK_LINES)
    ]
    paragraphs: list[str] = []
    buf: list[str] = []
    for ln in lines + [""]:
        if ln.strip():
            buf.append(ln.strip())
        elif buf:
            paragraphs.append(re.sub(r"\s+", " ", " ".join(buf)))
            buf = []
    return "\n\n".join(paragraphs)


def _split_long(paragraph: str) -> list[str]:
    """Parte un parrafo demasiado largo por frases, sin superar MAX_CHARS."""
    out: list[str] = []
    cur = ""
    for sentence in _SENTENCE_SPLIT.split(paragraph):
        while len(sentence) > MAX_CHARS:  # frase enorme: corte duro en un espacio
            cut = sentence.rfind(" ", 0, MAX_CHARS)
            cut = cut if cut > MAX_CHARS // 2 else MAX_CHARS
            if cur:
                out.append(cur)
                cur = ""
            out.append(sentence[:cut].strip())
            sentence = sentence[cut:].strip()
        if cur and len(cur) + 1 + len(sentence) > MAX_CHARS:
            out.append(cur)
            cur = sentence
        else:
            cur = f"{cur} {sentence}".strip()
    if cur:
        out.append(cur)
    return out


def is_useful(chunk: str) -> bool:
    if len(chunk) < MIN_CHUNK_CHARS or len(chunk.split()) < MIN_WORDS:
        return False
    letters = sum(c.isalpha() for c in chunk)
    return letters / len(chunk) >= MIN_LETTER_RATIO


def chunk_page(text: str) -> list[str]:
    """Agrupa los parrafos de una pagina en fragmentos de ~TARGET_CHARS."""
    pieces: list[str] = []
    for para in text.split("\n\n"):
        para = para.strip()
        if para:
            pieces.extend(_split_long(para) if len(para) > MAX_CHARS else [para])
    chunks: list[str] = []
    cur = ""
    for piece in pieces:
        if cur and len(cur) + 1 + len(piece) > MAX_CHARS:
            chunks.append(cur)
            cur = piece
        else:
            cur = f"{cur} {piece}".strip()
        if len(cur) >= TARGET_CHARS:
            chunks.append(cur)
            cur = ""
    if cur:
        # resto corto: se pega al fragmento anterior si cabe
        if chunks and len(cur) < MIN_CHUNK_CHARS * 2 and len(chunks[-1]) + 1 + len(cur) <= MAX_CHARS:
            chunks[-1] = f"{chunks[-1]} {cur}"
        else:
            chunks.append(cur)
    return [c for c in chunks if is_useful(c)]


def detect_chapter(text: str, current: str | None) -> str | None:
    for ln in text.split("\n"):
        m = _CHAPTER.match(ln)
        if m and len(m.group(1)) <= 90:
            return m.group(1).strip()
    return current


# ---------------------------------------------------------------------------
# Extraccion: texto + OCR
# ---------------------------------------------------------------------------


def _run(cmd: list[str], *, env: dict[str, str] | None = None) -> bytes:
    r = subprocess.run(cmd, capture_output=True, env=env)
    if r.returncode != 0:
        raise RuntimeError(f"{cmd[0]} fallo ({r.returncode}): {r.stderr.decode(errors='replace')[:300]}")
    return r.stdout


def pdf_text_pages(pdf: Path) -> list[str]:
    """Texto de cada pagina (pdftotext separa las paginas con \\f)."""
    raw = _run(["pdftotext", "-enc", "UTF-8", str(pdf), "-"]).decode("utf-8", "replace")
    pages = raw.split("\f")
    if pages and not pages[-1].strip():
        pages.pop()
    return pages


def ocr_page(pdf: Path, page: int, lang: str, cache_file: Path) -> str:
    if cache_file.exists():
        return cache_file.read_text(encoding="utf-8")
    env = dict(os.environ, OMP_THREAD_LIMIT="1")  # un hilo por proceso: el paralelismo lo damos nosotros
    with tempfile.TemporaryDirectory() as td:
        prefix = Path(td) / "p"
        _run(["pdftoppm", "-f", str(page), "-l", str(page), "-r", "200", "-gray", "-png", str(pdf), str(prefix)])
        image = next(Path(td).glob("p*.png"))
        text = _run(["tesseract", str(image), "stdout", "-l", lang, "--psm", "3"], env=env).decode("utf-8", "replace")
    cache_file.parent.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(text, encoding="utf-8")
    return text


@dataclass
class BookResult:
    info: BookInfo
    pdf: Path
    pages: int = 0
    ocr_pages: int = 0
    chunks: list[tuple[int, str | None, int, str]] = field(default_factory=list)  # (grade-agnostic) page, chapter, text


def process_book(pdf: Path, info: BookInfo, cache_root: Path, pool: cf.Executor | None, log) -> BookResult:
    texts = pdf_text_pages(pdf)
    result = BookResult(info=info, pdf=pdf, pages=len(texts))
    key = hashlib.sha1(f"{pdf.name}:{pdf.stat().st_size}".encode()).hexdigest()[:10]
    cache_dir = cache_root / f"{pdf.stem}_{key}"

    needs_ocr = [i for i, t in enumerate(texts) if len(t.strip()) < MIN_PAGE_CHARS]
    if needs_ocr:
        log(f"  OCR de {len(needs_ocr)}/{len(texts)} paginas ({info.ocr_lang})...")
        started = time.time()
        jobs = {
            i: (pool.submit(ocr_page, pdf, i + 1, info.ocr_lang, cache_dir / f"{i + 1:04d}.txt") if pool else None)
            for i in needs_ocr
        }
        done = 0
        for i, fut in jobs.items():
            texts[i] = fut.result() if fut else ocr_page(pdf, i + 1, info.ocr_lang, cache_dir / f"{i + 1:04d}.txt")
            done += 1
            if done % 25 == 0:
                log(f"    {done}/{len(needs_ocr)} ({time.time() - started:.0f}s)")
        result.ocr_pages = len(needs_ocr)

    chapter: str | None = None
    seen: set[str] = set()
    for i, raw in enumerate(texts):
        cleaned = clean_page(raw)
        chapter = detect_chapter(cleaned, chapter)
        for chunk in chunk_page(cleaned):
            norm = re.sub(r"\W+", " ", chunk.lower()).strip()
            if norm in seen:
                continue
            seen.add(norm)
            result.chunks.append((i + 1, chapter, chunk))
    return result


# ---------------------------------------------------------------------------
# Base de datos
# ---------------------------------------------------------------------------

_DDL = """
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);
CREATE TABLE chunks (
  id      INTEGER PRIMARY KEY,
  grade   INTEGER NOT NULL,
  subject TEXT    NOT NULL,
  book    TEXT,
  chapter TEXT,
  page    INTEGER,
  text    TEXT    NOT NULL
);
CREATE INDEX chunks_grade_subject ON chunks(grade, subject);
CREATE VIRTUAL TABLE chunks_fts USING fts5(
  text, content='chunks', content_rowid='id',
  tokenize='unicode61 remove_diacritics 2'
);
"""


def write_db(out: Path, results: list[BookResult]) -> dict[str, int]:
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(out.suffix + ".tmp")
    tmp.unlink(missing_ok=True)
    db = sqlite3.connect(tmp)
    try:
        db.executescript(_DDL)
        counts: dict[str, int] = {}
        books_meta = []
        for r in results:
            subject = r.info.subject or "General"
            n = 0
            for grade in r.info.grades:
                for page, chapter, text in r.chunks:
                    db.execute(
                        "INSERT INTO chunks(grade, subject, book, chapter, page, text) VALUES (?,?,?,?,?,?)",
                        (grade, subject, r.info.stem, chapter, page, text),
                    )
                    n += 1
            counts[r.info.stem] = n
            books_meta.append({
                "file": r.pdf.name, "subject": subject, "grades": list(r.info.grades),
                "kind": r.info.kind, "pages": r.pages, "ocr_pages": r.ocr_pages, "chunks": n,
            })
        db.execute("INSERT INTO chunks_fts(rowid, text) SELECT id, text FROM chunks")
        db.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('optimize')")
        meta = {
            "schema_version": SCHEMA_VERSION,
            "built_with": BUILDER_NAME,
            "built_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "books": json.dumps(books_meta, ensure_ascii=False),
        }
        db.executemany("INSERT INTO meta VALUES (?, ?)", meta.items())
        db.commit()
        db.execute("VACUUM")
    finally:
        db.close()
    tmp.replace(out)
    return counts


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--books", type=Path, default=Path("libros"), help="carpeta con los PDF")
    ap.add_argument("--out", type=Path, default=Path("build/knowledge.db"))
    ap.add_argument("--cache", type=Path, default=Path("build/ocr_cache"), help="cache del OCR (reanudable)")
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) // 2), help="procesos de OCR en paralelo")
    ap.add_argument("--only", action="append", default=[], help="procesa solo estos libros (nombre sin .pdf); repetible")
    args = ap.parse_args(argv)

    def log(msg: str) -> None:
        print(msg, file=sys.stderr, flush=True)

    for tool in ("pdftotext", "pdftoppm", "tesseract"):
        if subprocess.run(["which", tool], capture_output=True).returncode != 0:
            log(f"Falta '{tool}'. Instala poppler-utils y tesseract (con spa y eng).")
            return 2

    pdfs = sorted(args.books.glob("*.pdf"))
    if args.only:
        pdfs = [p for p in pdfs if p.stem in args.only]
    if not pdfs:
        log(f"No hay PDF en {args.books}")
        return 1

    results: list[BookResult] = []
    warnings: list[str] = []
    started = time.time()
    with cf.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for pdf in pdfs:
            info = parse_filename(pdf.stem)
            log(f"{pdf.name}  ->  grados {list(info.grades) or '?'}, {info.subject or '?'} ({info.kind})")
            if not info.grades:
                warnings.append(f"{pdf.name}: el nombre no empieza por un grado (1ro_, 4to_...); se omite")
                continue
            if info.subject is None:
                warnings.append(f"{pdf.name}: asignatura no reconocida; se guarda como 'General'")
            results.append(process_book(pdf, info, args.cache, pool, log))

    counts = write_db(args.out, results)

    print(f"\n{'libro':<40}{'grados':<10}{'págs':>6}{'OCR':>6}{'frags':>8}")
    for r in results:
        grades = ",".join(map(str, r.info.grades))
        print(f"{r.info.stem:<40}{grades:<10}{r.pages:>6}{r.ocr_pages:>6}{counts[r.info.stem]:>8}")
        if r.pages and len(r.chunks) / r.pages < 0.5:
            warnings.append(f"{r.pdf.name}: solo {len(r.chunks)} fragmentos en {r.pages} paginas (¿OCR pobre o libro de imagenes?)")
    print(f"\nTotal: {sum(counts.values())} fragmentos de {len(results)} libros -> {args.out} "
          f"({args.out.stat().st_size / 1e6:.1f} MB, {time.time() - started:.0f}s)")
    for w in warnings:
        print(f"AVISO: {w}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
