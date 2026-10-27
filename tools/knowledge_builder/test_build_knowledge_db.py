"""Pruebas del constructor: python3 -m unittest discover -s tools/knowledge_builder"""
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import build_knowledge_db as kb  # noqa: E402


class ParseFilename(unittest.TestCase):
    def test_libro_simple(self):
        i = kb.parse_filename("6to_ciencias_naturales")
        self.assertEqual((i.grades, i.subject, i.kind), ((6,), "Ciencias Naturales", "Libro"))

    def test_varios_grados(self):
        i = kb.parse_filename("1ro_2do_ca_el_mundo")
        self.assertEqual(i.grades, (1, 2))
        self.assertEqual(i.subject, "El mundo en que vivimos")

    def test_cuadernos(self):
        self.assertEqual(kb.parse_filename("1ro_ct_matematica").kind, "Cuaderno")
        self.assertEqual(kb.parse_filename("4to_cuaderno_ortografia").kind, "Cuaderno")
        self.assertEqual(kb.parse_filename("6to_english_workbook").kind, "Cuaderno")
        self.assertEqual(kb.parse_filename("6to_esp").kind, "Libro")

    def test_asignaturas(self):
        casos = {
            "4to_esp_II": "Español",
            "6to_cuaderno_ortografia": "Español",
            "3ro_english": "Inglés",
            "4to_ingles": "Inglés",
            "6to_new_roads_english_english": "Inglés",
            "5to_ca_historia_cuba": "Historia de Cuba",
            "6to_ca_geografia": "Geografía",
            "6to_ct_edu_civica": "Educación Cívica",
            "5to_edu_laboral": "Educación Laboral",
            "5to_ciencias": "Ciencias Naturales",
            "6to_ct_ciencias": "Ciencias Naturales",
            "6to_ciencias_naturales_2": "Ciencias Naturales",
            "4to_mundo-digital": "Mundo Digital",
            "6to_ct_historia-cuba": "Historia de Cuba",
            "6to_historia-cuba": "Historia de Cuba",
            "2do_ct_lengua": "Español",
            "4to_el_mundo_en_que_vivimos": "El mundo en que vivimos",
            "1ro_ct_matematica": "Matemática",
        }
        for stem, subject in casos.items():
            with self.subTest(stem):
                self.assertEqual(kb.parse_filename(stem).subject, subject)

    def test_idioma_del_ocr(self):
        self.assertEqual(kb.parse_filename("4to_ingles").ocr_lang, "eng+spa")
        self.assertEqual(kb.parse_filename("4to_esp_II").ocr_lang, "spa")

    def test_sin_grado_ni_asignatura(self):
        i = kb.parse_filename("atlas_mundial")
        self.assertEqual(i.grades, ())
        self.assertIsNone(i.subject)

    def test_grados_altos(self):
        self.assertEqual(kb.parse_filename("10mo_fisica").grades, (10,))


class CleanAndChunk(unittest.TestCase):
    def test_quita_ruido_de_maquetacion(self):
        raw = "5PR019 CIENCIAS NATURALES 23-Jun-15 10:37 AM Página G\n\n12\nLas plantas necesitan luz.\n6A-14\n10:34"
        self.assertEqual(kb.clean_page(raw), "Las plantas necesitan luz.")

    def test_quita_marca_de_imprenta_pegada_al_texto(self):
        raw = "6A-14 1/3/07 10:34 Página 7 Este libro forma parte del conjunto de trabajos."
        self.assertEqual(kb.clean_page(raw), "Este libro forma parte del conjunto de trabajos.")

    def test_une_palabras_partidas(self):
        self.assertEqual(kb.clean_page("La informa-\nción es útil."), "La información es útil.")

    def test_no_une_guiones_legitimos(self):
        self.assertIn("Cuba-", kb.clean_page("Cuba-\nEspaña"))

    def test_une_lineas_de_un_parrafo(self):
        self.assertEqual(kb.clean_page("uno dos\ntres cuatro\n\ncinco"), "uno dos tres cuatro\n\ncinco")

    def test_descarta_fragmentos_inutiles(self):
        self.assertFalse(kb.is_useful("1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25"))
        self.assertFalse(kb.is_useful("muy corto"))
        self.assertTrue(kb.is_useful("Las plantas fabrican su alimento con la luz del sol en las hojas verdes."))

    def test_fragmentos_acotados(self):
        parrafo = " ".join(f"Esta es la frase número {i} del texto." for i in range(120))
        for c in kb.chunk_page(parrafo):
            self.assertLessEqual(len(c), kb.MAX_CHARS)
        self.assertGreater(len(kb.chunk_page(parrafo)), 3)

    def test_junta_parrafos_cortos(self):
        texto = "\n\n".join(["Las plantas fabrican su alimento con luz del sol y agua del suelo."] * 4)
        chunks = kb.chunk_page(texto)
        self.assertEqual(len(chunks), 1)
        self.assertLessEqual(len(chunks[0]), kb.MAX_CHARS)

    def test_frase_gigante_sin_puntos(self):
        chunks = kb.chunk_page("palabra " * 600)
        self.assertTrue(all(len(c) <= kb.MAX_CHARS for c in chunks))

    def test_detecta_capitulos(self):
        self.assertEqual(kb.detect_chapter("Capítulo 3 Los seres vivos\ntexto", None), "Capítulo 3 Los seres vivos")
        self.assertEqual(kb.detect_chapter("sin titulo", "Unidad 2"), "Unidad 2")


class WriteDb(unittest.TestCase):
    def test_esquema_y_busqueda(self):
        info = kb.parse_filename("1ro_2do_ca_el_mundo")
        res = kb.BookResult(info=info, pdf=Path("1ro_2do_ca_el_mundo.pdf"), pages=2, ocr_pages=1)
        res.chunks = [(1, "Capítulo 1", "La fotosíntesis es el proceso por el que las plantas fabrican su alimento con luz.")]
        with tempfile.TemporaryDirectory() as td:
            out = Path(td) / "k.db"
            counts = kb.write_db(out, [res])
            self.assertEqual(counts["1ro_2do_ca_el_mundo"], 2)  # un fragmento por grado
            db = sqlite3.connect(out)
            self.assertEqual(db.execute("SELECT value FROM meta WHERE key='schema_version'").fetchone()[0], "1")
            self.assertEqual([r[0] for r in db.execute("SELECT DISTINCT grade FROM chunks ORDER BY grade")], [1, 2])
            hit = db.execute(
                "SELECT c.grade FROM chunks_fts f JOIN chunks c ON c.id=f.rowid "
                "WHERE chunks_fts MATCH 'fotosintesis' AND c.grade=2"
            ).fetchall()
            self.assertEqual(hit, [(2,)])  # sin tildes y filtrando por grado
            self.assertFalse(Path(str(out) + ".tmp").exists())


if __name__ == "__main__":
    unittest.main()
