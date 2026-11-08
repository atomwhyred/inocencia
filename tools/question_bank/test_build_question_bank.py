"""Pruebas del banco de preguntas: python3 -m unittest discover -s tools/question_bank"""
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import build_question_bank as qb  # noqa: E402

LIBRO = (
    "Las plantas tienen raíces, tallo y hojas. Las raíces sostienen la planta en el suelo "
    "y absorben el agua y las sales minerales que la planta necesita para vivir y crecer."
)

MODELO = """P1: ¿Qué absorben las raíces?
A) Luz
B) Agua
C) Aire
RESPUESTA: B
P2: ¿Qué hay en la página 12?
A) raíces
B) tallo
C) hojas
RESPUESTA: A
**P3:** ¿Dónde sostienen las raíces a la planta?
A) En el suelo
B) En el cielo
C) En el mar
Respuesta correcta: A
P4: ¿Pregunta incompleta?
A) uno
RESPUESTA: A
"""


class Parser(unittest.TestCase):
    def test_lee_el_formato_del_quiz_y_descarta_lo_incompleto(self):
        qs = qb.parse_questions(MODELO)
        self.assertEqual(len(qs), 3)
        self.assertEqual(qs[0].text, "¿Qué absorben las raíces?")
        self.assertEqual(qs[0].options, ("Luz", "Agua", "Aire"))
        self.assertEqual(qs[0].correct, 1)
        self.assertEqual(qs[2].correct, 0)


class Filtros(unittest.TestCase):
    def test_la_correcta_tiene_que_salir_del_libro(self):
        ok, pagina, suelo = qb.parse_questions(MODELO)
        self.assertTrue(qb.is_grounded(ok, LIBRO))
        self.assertFalse(qb.is_grounded(pagina, LIBRO), "depende de una página")
        self.assertTrue(qb.is_grounded(suelo, LIBRO))
        mal = qb.Question("¿Qué absorben?", ("Luz", "Agua", "Aire"), 0)
        self.assertFalse(qb.is_grounded(mal, LIBRO), "'luz' no está en el libro")

    def test_opciones_repetidas_o_que_citan_la_maqueta(self):
        rep = qb.Question("¿Qué absorben?", ("Agua", "agua", "Aire"), 0)
        self.assertFalse(qb.is_grounded(rep, LIBRO))
        tabla = qb.Question("¿Qué absorben?", ("Agua", "La tabla", "Aire"), 0)
        self.assertFalse(qb.is_grounded(tabla, LIBRO))

    def test_preguntas_cortas_que_acaban_en_interrogacion(self):
        self.assertTrue(qb.is_kid_friendly(qb.Question("¿Qué es?", ("a", "b", "c"), 0)))
        self.assertFalse(qb.is_kid_friendly(qb.Question("Di qué es", ("a", "b", "c"), 0)))
        self.assertFalse(qb.is_kid_friendly(qb.Question("¿Qué es?", ("a" * 61, "b", "c"), 0)))
        jeans = qb.Question("¿Cuál es el singular de jeans?", ("skirt", "trousers", "jeans"), 2)
        self.assertFalse(qb.is_kid_friendly(jeans), "la respuesta está en la pregunta")

    def test_fragmentos_utiles(self):
        self.assertTrue(qb.is_useful_chunk(LIBRO * 2))
        self.assertFalse(qb.is_useful_chunk("corto"))
        self.assertFalse(qb.is_useful_chunk(LIBRO + " José ________ la carretera. " + LIBRO))
        self.assertFalse(qb.is_useful_chunk("Fig. 169 " + LIBRO * 2))
        self.assertFalse(qb.is_useful_chunk("13. Lee esto. 14. Copia. 15. Escribe. " + LIBRO * 2))

    def test_no_repite_preguntas(self):
        chunk = qb.Chunk(1, 4, "Ciencias", "4to_ciencias", 10, LIBRO)
        seen: set[str] = set()
        self.assertEqual(len(qb.accept(chunk, MODELO, seen)), 2)
        self.assertEqual(qb.accept(chunk, MODELO, seen), [], "las mismas preguntas otra vez")


class Prompt(unittest.TestCase):
    def test_grado_y_libro(self):
        self.assertIn("4.º grado", qb.system_prompt(4))
        self.assertIn("1.er grado", qb.system_prompt(1))
        chunk = qb.Chunk(1, 4, "Español", "4to_esp", 89, "texto")
        self.assertIn("Español · 4to_esp · pág. 89", qb.user_prompt(chunk))


class Tabla(unittest.TestCase):
    def _db(self, d: Path) -> Path:
        p = d / "k.db"
        db = sqlite3.connect(p)
        db.execute("CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)")
        db.execute("INSERT INTO meta VALUES ('schema_version', '1')")
        db.execute(
            "CREATE TABLE chunks (id INTEGER PRIMARY KEY, grade INTEGER, subject TEXT, book TEXT,"
            " chapter TEXT, page INTEGER, text TEXT)"
        )
        for i in range(6):
            db.execute(
                "INSERT INTO chunks (grade, subject, book, page, text) VALUES (4, ?, 'b', ?, ?)",
                ("Ciencias" if i % 2 else "Español", i, LIBRO * 2),
            )
        db.commit()
        db.close()
        return p

    def test_escribe_exporta_e_importa(self):
        with tempfile.TemporaryDirectory() as d:
            db = self._db(Path(d))
            chunk = qb.Chunk(1, 4, "Ciencias", "4to_ciencias", 10, LIBRO)
            rows = qb.accept(chunk, MODELO, set())
            qb.write_table(db, rows)
            con = sqlite3.connect(db)
            self.assertEqual(con.execute("SELECT count(*) FROM game_questions").fetchone()[0], 2)
            self.assertEqual(con.execute("SELECT value FROM meta WHERE key='game_questions'").fetchone()[0], "2")
            self.assertEqual(con.execute("SELECT value FROM meta WHERE key='schema_version'").fetchone()[0], "1")
            con.close()

            csv_path = Path(d) / "q.csv"
            qb.export_csv(csv_path, rows)
            lines = csv_path.read_text(encoding="utf-8").splitlines()
            # Un adulto borra la segunda pregunta y corrige la primera.
            csv_path.write_text("\n".join([lines[0], lines[1].replace("Luz", "Sol")]) + "\n", encoding="utf-8")
            back = qb.import_csv(csv_path)
            self.assertEqual(len(back), 1)
            self.assertEqual(back[0].question.options[0], "Sol")
            qb.write_table(db, back)
            con = sqlite3.connect(db)
            self.assertEqual(con.execute("SELECT count(*) FROM game_questions").fetchone()[0], 1)
            con.close()

    def test_prefiere_libros_a_cuadernos(self):
        self.assertTrue(qb.is_workbook("4to_ct_matematica"))
        self.assertTrue(qb.is_workbook("6to_english_workbook"))
        self.assertTrue(qb.is_workbook("4to_cuaderno_ortografia"))
        self.assertFalse(qb.is_workbook("4to_matematica"))
        with tempfile.TemporaryDirectory() as d:
            p = self._db(Path(d))
            con = sqlite3.connect(p)
            # Una sola asignatura, mitad libro y mitad cuaderno: salen primero los del libro.
            con.execute("UPDATE chunks SET subject = 'Ciencias'")
            con.execute("UPDATE chunks SET book = '4to_ct_ciencias' WHERE id % 2 = 0")
            con.commit()
            picked = qb.pick_chunks(con, 4, 3)
            con.close()
            self.assertTrue(all(not qb.is_workbook(c.book) for c in picked))

    def test_reparte_fragmentos_entre_asignaturas(self):
        with tempfile.TemporaryDirectory() as d:
            con = sqlite3.connect(self._db(Path(d)))
            picked = qb.pick_chunks(con, 4, 4)
            con.close()
            self.assertEqual(len(picked), 4)
            self.assertEqual({c.subject for c in picked}, {"Ciencias", "Español"})

    def test_sin_ingles(self):
        with tempfile.TemporaryDirectory() as d:
            con = sqlite3.connect(self._db(Path(d)))
            con.execute("UPDATE chunks SET subject = 'Inglés' WHERE subject = 'Ciencias'")
            con.commit()
            picked = qb.pick_chunks(con, 4, 6)
            con.close()
            self.assertEqual({c.subject for c in picked}, {"Español"})


if __name__ == "__main__":
    unittest.main()
