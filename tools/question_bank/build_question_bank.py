#!/usr/bin/env python3
"""Genera el banco de preguntas del juego ("Carrera de tocororos") dentro de knowledge.db.

Uso (en el PC, con llama-server compilado en native/llama/build/host):

    python3 tools/question_bank/build_question_bank.py \\
        --db build/knowledge.db \\
        --llama-server native/llama/build/host/bin/llama-server \\
        --model models/qwen2.5-3b-instruct-q4_0.gguf \\
        --per-grade 150

Por cada grado (1-6) toma fragmentos utiles del libro, pide al modelo 3 preguntas de
opcion multiple por fragmento (el mismo formato que el quiz de la app) y se queda solo
con las que pasan los mismos filtros que la app (`QuizParser` y `QuizGrounding`):
la respuesta correcta aparece en el texto del libro, la pregunta no depende de una
pagina o un dibujo y las opciones no se repiten.

Las respuestas del modelo se guardan en una cache (`--cache`): relanzar el script no
repite el trabajo, y se puede parar en cualquier momento.

Al terminar escribe la tabla `game_questions` en el .db (ver docs/knowledge_db_schema.md)
y exporta `build/game_questions.csv` para que un adulto lo revise. Para cargar el CSV
corregido (filas borradas o editadas): `--import-csv build/game_questions.csv`.

Sin dependencias fuera de la libreria estandar.
"""
from __future__ import annotations

import argparse
import csv
import json
import random
import re
import sqlite3
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

QUESTIONS_PER_CHUNK = 3
MAX_TOKENS = 420

# ---------------------------------------------------------------------------
# Reglas portadas de la app (lib/core/utils/plain_text.dart, lib/features/quiz/)
# ---------------------------------------------------------------------------


def plain_text(s: str) -> str:
    """Igual que `plainText` de la app: sin mayusculas, tildes ni signos."""
    t = s.lower()
    t = t.translate(str.maketrans("áéíóúüñ", "aeiouun"))
    t = re.sub(r"[^a-z0-9 ]", " ", t)
    return re.sub(r" +", " ", t).strip()


_LAYOUT = re.compile(r"\b(pagina|recuadro|ejercicio|imagen|dibujo|figura|texto|tabla|poema|lectura)\b")


def depends_on_book_layout(text: str) -> bool:
    """`dependsOnBookLayout` de la app, mas tabla/poema/lectura (el nino no los ve)."""
    return bool(_LAYOUT.search(plain_text(text)))


def grade_label(grade: int) -> str:
    if grade <= 0:
        return "Preescolar"
    if grade == 1:
        return "1.er grado"
    return f"{grade}.º grado"


@dataclass(frozen=True)
class Question:
    text: str
    options: tuple[str, str, str]
    correct: int  # 0, 1 o 2


_Q = re.compile(r"^\s*(?:pregunta|p)?\s*\d+\s*[:.)\-]\s*(.+)$", re.IGNORECASE)
_OPT = re.compile(r"^\s*\(?([ABCabc])\s*[).:\-]\s*(.+)$")
_ANS = re.compile(r"^\s*(?:respuesta(?:\s+correcta)?|correcta)\s*[:=\-]?\s*\(?\s*([ABCabc])\b", re.IGNORECASE)


def parse_questions(raw: str) -> list[Question]:
    """`QuizParser.parse`: tolerante con el formato, descarta lo mal formado."""
    out: list[Question] = []
    text: str | None = None
    options: list[str | None] = [None, None, None]
    correct: int | None = None

    def close() -> None:
        nonlocal text, options, correct
        if text is not None and correct is not None and all(options):
            out.append(Question(text, (options[0], options[1], options[2]), correct))  # type: ignore[arg-type]
        text, options, correct = None, [None, None, None], None

    for line in raw.replace("**", "").split("\n"):
        m = _ANS.match(line)
        if m:
            correct = "abc".index(m.group(1).lower())
            continue
        m = _OPT.match(line)
        if m and text is not None:
            options["abc".index(m.group(1).lower())] = m.group(2).strip()
            continue
        m = _Q.match(line)
        if m:
            close()
            text = m.group(1).strip()
    close()
    return out


def is_grounded(q: Question, book_text: str) -> bool:
    """`QuizGrounding.isGrounded`: la correcta sale del libro y nada depende de la maqueta."""
    if depends_on_book_layout(q.text):
        return False
    options = [plain_text(o) for o in q.options]
    if len(set(options)) != len(options) or any(not o for o in options):
        return False
    if any(depends_on_book_layout(o) for o in q.options):
        return False
    return f" {options[q.correct]} " in f" {plain_text(book_text)} "


def is_kid_friendly(q: Question) -> bool:
    """Preguntas que se leen bien en el juego: cortas, con opciones cortas y sin la
    respuesta escrita en la propia pregunta ("¿Cuál es el singular de jeans? -> jeans")."""
    if len(q.text) > 160 or not q.text.rstrip().endswith("?"):
        return False
    if not all(0 < len(o) <= 60 for o in q.options):
        return False
    return f" {plain_text(q.options[q.correct])} " not in f" {plain_text(q.text)} "


# ---------------------------------------------------------------------------
# Fragmentos del libro
# ---------------------------------------------------------------------------

_EXERCISE_NUMBER = re.compile(r"(?:^|\s)\d{1,2}\.\s")


def is_useful_chunk(text: str) -> bool:
    """Fragmentos que explican algo, no ejercicios a medias del OCR."""
    t = text.strip()
    if len(t) < 250:
        return False
    if "___" in t or "…………" in t or "...." in t:
        return False
    if re.search(r"\bFig\.?\s*\d", t):
        return False
    if len(_EXERCISE_NUMBER.findall(t)) > 1:
        return False
    if t.count("?") > 2 or t.count("=") > 2:
        return False
    letters = sum(c.isalpha() for c in t)
    return letters / len(t) > 0.7


@dataclass(frozen=True)
class Chunk:
    id: int
    grade: int
    subject: str
    book: str | None
    page: int | None
    text: str


_WORKBOOK = re.compile(r"(?:^|_)(?:ct|cuaderno|workbook)(?:_|$)", re.IGNORECASE)


def is_workbook(book: str | None) -> bool:
    """Cuadernos de ejercicios: casi todo son actividades ("observa la figura", "completa la tabla")."""
    return bool(book and _WORKBOOK.search(book))


# El modelo y el filtro no saben validar preguntas en inglés: salían palabras sueltas sin sentido.
SKIP_SUBJECTS = {"Inglés", "English"}


def pick_chunks(db: sqlite3.Connection, grade: int, count: int, seed: int = 7) -> list[Chunk]:
    """Fragmentos utiles del grado, repartidos por asignatura (turnos) y en orden fijo.
    Primero los de los libros; los de los cuadernos, solo si no alcanzan."""
    rows = db.execute(
        "SELECT id, grade, subject, book, page, text FROM chunks WHERE grade = ? ORDER BY id", (grade,)
    ).fetchall()
    by_subject: dict[str, list[Chunk]] = {}
    for r in rows:
        c = Chunk(*r)
        if c.subject not in SKIP_SUBJECTS and is_useful_chunk(c.text):
            by_subject.setdefault(c.subject, []).append(c)
    rng = random.Random(seed * 100 + grade)
    for lst in by_subject.values():
        rng.shuffle(lst)
        # Se sacan con pop(): los de libro van al final para salir primero.
        lst.sort(key=lambda c: not is_workbook(c.book))
    out: list[Chunk] = []
    subjects = sorted(by_subject)
    while len(out) < count and any(by_subject[s] for s in subjects):
        for s in subjects:
            if by_subject[s] and len(out) < count:
                out.append(by_subject[s].pop())
    return out


# ---------------------------------------------------------------------------
# Modelo (llama-server, API compatible con OpenAI)
# ---------------------------------------------------------------------------


def system_prompt(grade: int) -> str:
    """El mismo que `QuizPrompt.system` de la app."""
    return (
        f"Eres inocencIA, un maestro cubano. Preparas un cuestionario para un niño de {grade_label(grade)}.\n"
        "Reglas:\n"
        f"- Haz exactamente {QUESTIONS_PER_CHUNK} preguntas de opción múltiple con 3 opciones (A, B y C) y UNA sola correcta.\n"
        "- Usa SOLO los TEXTOS DEL LIBRO. Español sencillo y frases cortas.\n"
        "- Pregunta por datos que están escritos en el texto. La opción correcta es una palabra o frase corta copiada tal cual del texto.\n"
        "- La pregunta se debe entender sin el libro: NO menciones páginas, recuadros, tablas, poemas ni ejercicios.\n"
        "- La opción correcta sale del texto y las otras dos son claramente falsas (no sirven para esa pregunta).\n"
        "- Escribe EXACTAMENTE en este formato, sin nada más:\n"
        "P1: pregunta\nA) opción\nB) opción\nC) opción\nRESPUESTA: B"
    )


def user_prompt(chunk: Chunk) -> str:
    label = " · ".join(str(x) for x in (chunk.subject, chunk.book, f"pág. {chunk.page}" if chunk.page else None) if x)
    return f"TEXTOS DEL LIBRO:\n[1] {label}: {chunk.text}\n\nEscribe ahora las {QUESTIONS_PER_CHUNK} preguntas."


def ask_model(server: str, grade: int, chunk: Chunk, timeout: float = 600) -> str:
    body = json.dumps(
        {
            "messages": [
                {"role": "system", "content": system_prompt(grade)},
                {"role": "user", "content": user_prompt(chunk)},
            ],
            "temperature": 0.3,
            "top_p": 0.9,
            "max_tokens": MAX_TOKENS,
        }
    ).encode()
    req = urllib.request.Request(
        f"{server}/v1/chat/completions", data=body, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)["choices"][0]["message"]["content"]


def wait_for_server(server: str, seconds: float = 300) -> None:
    end = time.time() + seconds
    while time.time() < end:
        try:
            with urllib.request.urlopen(f"{server}/health", timeout=5) as r:
                if r.status == 200:
                    return
        except (urllib.error.URLError, ConnectionError, TimeoutError):
            pass
        time.sleep(2)
    raise RuntimeError(f"llama-server no responde en {server}")


# ---------------------------------------------------------------------------
# Banco: cache, tabla y CSV
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class BankRow:
    grade: int
    subject: str
    book: str | None
    page: int | None
    question: Question


def load_cache(path: Path) -> dict[str, str]:
    return json.loads(path.read_text()) if path.exists() else {}


def save_cache(path: Path, cache: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(cache, ensure_ascii=False, indent=0))
    tmp.replace(path)


def accept(chunk: Chunk, raw: str, seen: set[str]) -> list[BankRow]:
    """Preguntas validas de una respuesta del modelo, sin repetir las ya vistas."""
    out = []
    for q in parse_questions(raw):
        key = plain_text(q.text)
        if key in seen or not is_kid_friendly(q) or not is_grounded(q, chunk.text):
            continue
        seen.add(key)
        out.append(BankRow(chunk.grade, chunk.subject, chunk.book, chunk.page, q))
    return out


TABLE_SQL = """
CREATE TABLE game_questions (
  id       INTEGER PRIMARY KEY,
  grade    INTEGER NOT NULL,
  subject  TEXT    NOT NULL,
  book     TEXT,
  page     INTEGER,
  question TEXT    NOT NULL,
  a        TEXT    NOT NULL,
  b        TEXT    NOT NULL,
  c        TEXT    NOT NULL,
  correct  INTEGER NOT NULL CHECK (correct IN (0, 1, 2))
)
"""


def write_table(db_path: Path, rows: list[BankRow]) -> None:
    db = sqlite3.connect(db_path)
    try:
        with db:
            db.execute("DROP TABLE IF EXISTS game_questions")
            db.execute(TABLE_SQL)
            db.execute("CREATE INDEX game_questions_grade ON game_questions(grade)")
            db.executemany(
                "INSERT INTO game_questions (grade, subject, book, page, question, a, b, c, correct)"
                " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    (r.grade, r.subject, r.book, r.page, r.question.text, *r.question.options, r.question.correct)
                    for r in rows
                ],
            )
            db.execute(
                "INSERT OR REPLACE INTO meta (key, value) VALUES ('game_questions', ?)", (str(len(rows)),)
            )
    finally:
        db.close()


CSV_FIELDS = ["grado", "asignatura", "libro", "pagina", "pregunta", "A", "B", "C", "correcta"]


def export_csv(path: Path, rows: list[BankRow]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(CSV_FIELDS)
        for r in rows:
            q = r.question
            w.writerow([r.grade, r.subject, r.book or "", r.page or "", q.text, *q.options, "ABC"[q.correct]])


def import_csv(path: Path) -> list[BankRow]:
    rows = []
    with path.open(newline="", encoding="utf-8") as f:
        for line in csv.DictReader(f):
            letter = line["correcta"].strip().upper()
            if letter not in ("A", "B", "C") or not line["pregunta"].strip():
                continue
            q = Question(
                line["pregunta"].strip(),
                (line["A"].strip(), line["B"].strip(), line["C"].strip()),
                "ABC".index(letter),
            )
            if not all(q.options):
                continue
            rows.append(
                BankRow(
                    int(line["grado"]),
                    line["asignatura"],
                    line["libro"] or None,
                    int(line["pagina"]) if line["pagina"] else None,
                    q,
                )
            )
    return rows


# ---------------------------------------------------------------------------


def build(args: argparse.Namespace) -> list[BankRow]:
    db = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
    cache = load_cache(args.cache)
    rows: list[BankRow] = []
    try:
        for grade in args.grades:
            seen: set[str] = set()
            kept: list[BankRow] = []
            # Hacen falta mas fragmentos que preguntas: el filtro descarta muchas.
            chunks = pick_chunks(db, grade, args.per_grade * 2)
            print(f"[{grade_label(grade)}] {len(chunks)} fragmentos utiles", flush=True)
            started = time.time()
            asked = 0
            for chunk in chunks:
                if len(kept) >= args.per_grade:
                    break
                key = str(chunk.id)
                if key not in cache:
                    if args.offline:
                        continue
                    try:
                        cache[key] = ask_model(args.server, grade, chunk)
                    except (urllib.error.URLError, TimeoutError, KeyError) as e:
                        print(f"  fragmento {chunk.id}: el modelo fallo ({e})", file=sys.stderr)
                        continue
                    asked += 1
                    save_cache(args.cache, cache)
                kept += accept(chunk, cache[key], seen)
                if asked and asked % 5 == 0:
                    per = (time.time() - started) / asked
                    print(f"  {len(kept)}/{args.per_grade} preguntas, {per:.0f} s por fragmento", flush=True)
            print(f"[{grade_label(grade)}] {len(kept)} preguntas", flush=True)
            rows += kept[: args.per_grade]
    finally:
        db.close()
    return rows


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", type=Path, default=Path("build/knowledge.db"))
    ap.add_argument("--server", default="http://127.0.0.1:8099", help="llama-server ya arrancado")
    ap.add_argument("--llama-server", type=Path, help="arranca este llama-server con --model")
    ap.add_argument("--model", type=Path, default=Path("models/qwen2.5-3b-instruct-q4_0.gguf"))
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--grades", type=int, nargs="+", default=[1, 2, 3, 4, 5, 6])
    ap.add_argument("--per-grade", type=int, default=150)
    ap.add_argument("--cache", type=Path, default=Path("build/question_cache.json"))
    ap.add_argument("--csv", type=Path, default=Path("build/game_questions.csv"))
    ap.add_argument("--offline", action="store_true", help="solo usa la cache, sin llamar al modelo")
    ap.add_argument("--import-csv", type=Path, help="carga este CSV revisado en la tabla y termina")
    args = ap.parse_args(argv)

    if args.import_csv:
        rows = import_csv(args.import_csv)
        write_table(args.db, rows)
        print(f"{len(rows)} preguntas cargadas desde {args.import_csv} en {args.db}")
        return 0

    server = None
    if args.llama_server and not args.offline:
        port = args.server.rsplit(":", 1)[-1]
        server = subprocess.Popen(
            [str(args.llama_server), "-m", str(args.model), "--port", port, "-t", str(args.threads),
             "-c", "2048", "--host", "127.0.0.1"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        print(f"Arrancando llama-server ({args.model.name})...", flush=True)
    try:
        if not args.offline:
            wait_for_server(args.server)
        rows = build(args)
    finally:
        if server:
            server.terminate()
            server.wait(timeout=30)

    write_table(args.db, rows)
    export_csv(args.csv, rows)
    print(f"{len(rows)} preguntas en {args.db} (tabla game_questions); revisión: {args.csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
