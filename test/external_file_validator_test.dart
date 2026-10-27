import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/features/external_data/data/external_file_validator.dart';
import 'package:inocencia/features/external_data/domain/linked_file_status.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('inocencia_test_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String path(String name) => p.join(tmp.path, name);

  group('modelo GGUF', () {
    test('acepta la cabecera GGUF v3', () {
      File(path('m.gguf')).writeAsBytesSync([0x47, 0x47, 0x55, 0x46, 3, 0, 0, 0, 1, 2]);
      final s = ExternalFileValidator.validateModelSync(path('m.gguf'));
      expect(s.state, LinkState.ready);
      expect(s.sizeBytes, 10);
    });

    test('rechaza un archivo que no es GGUF', () {
      File(path('x.gguf')).writeAsStringSync('esto no es un modelo');
      expect(ExternalFileValidator.validateModelSync(path('x.gguf')).state, LinkState.invalid);
    });

    test('rechaza version de GGUF desconocida', () {
      File(path('v.gguf')).writeAsBytesSync([0x47, 0x47, 0x55, 0x46, 9, 0, 0, 0]);
      expect(ExternalFileValidator.validateModelSync(path('v.gguf')).state, LinkState.invalid);
    });

    test('archivo demasiado corto es invalido', () {
      File(path('c.gguf')).writeAsBytesSync([0x47, 0x47]);
      expect(ExternalFileValidator.validateModelSync(path('c.gguf')).state, LinkState.invalid);
    });

    test('archivo inexistente se reporta como missing', () {
      final s = ExternalFileValidator.validateModelSync(path('no.gguf'));
      expect(s.state, LinkState.missing);
      expect(s.path, path('no.gguf'));
    });
  });

  group('base de conocimiento', () {
    void createDb(String file, {String version = '1', bool withFts = true}) {
      final db = sqlite3.open(file);
      db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');
      db.execute(
        'CREATE TABLE chunks(id INTEGER PRIMARY KEY, grade INTEGER, subject TEXT, '
        'book TEXT, chapter TEXT, page INTEGER, text TEXT)',
      );
      if (withFts) {
        db.execute(
          "CREATE VIRTUAL TABLE chunks_fts USING fts5(text, content='chunks', "
          "content_rowid='id', tokenize='unicode61 remove_diacritics 2')",
        );
      }
      db.execute("INSERT INTO meta VALUES('schema_version', '$version')");
      db.execute("INSERT INTO chunks VALUES(1, 5, 'Matematica', 'Mat 5', 'Fracciones', 10, 'Una fraccion es una parte de un todo')");
      db.execute("INSERT INTO chunks VALUES(2, 5, 'Ciencias', 'Cie 5', 'Plantas', 22, 'Las plantas hacen la fotosintesis')");
      db.execute("INSERT INTO chunks VALUES(3, 0, 'Lengua', 'Len P', 'Vocales', 3, 'La a, la e, la i')");
      if (withFts) {
        db.execute("INSERT INTO chunks_fts(rowid, text) SELECT id, text FROM chunks");
      }
      db.close();
    }

    test('una base valida queda lista con sus datos', () {
      createDb(path('k.db'));
      final s = ExternalFileValidator.validateKnowledgeSync(path('k.db'));
      expect(s.state, LinkState.ready, reason: s.message);
      expect(s.chunkCount, 3);
      expect(s.grades, [0, 5]);
      expect(s.subjects, ['Ciencias', 'Lengua', 'Matematica']);
      expect(s.schemaVersion, '1');
    });

    test('SQLite incluye FTS5: MATCH con BM25 y filtro por grado', () {
      createDb(path('k.db'));
      final db = sqlite3.open(path('k.db'), mode: OpenMode.readOnly);
      final rows = db.select(
        'SELECT c.subject FROM chunks_fts f JOIN chunks c ON c.id = f.rowid '
        'WHERE chunks_fts MATCH ? AND c.grade = ? ORDER BY bm25(chunks_fts)',
        ['fotosintesis', 5],
      );
      db.close();
      expect(rows.map((r) => r['subject']), ['Ciencias']);
    });

    test('FTS5 ignora tildes (remove_diacritics)', () {
      createDb(path('k.db'));
      final db = sqlite3.open(path('k.db'), mode: OpenMode.readOnly);
      final rows = db.select(
        "SELECT rowid FROM chunks_fts WHERE chunks_fts MATCH 'fracción'",
      );
      db.close();
      expect(rows, hasLength(1));
    });

    test('faltan tablas', () {
      createDb(path('k.db'), withFts: false);
      final s = ExternalFileValidator.validateKnowledgeSync(path('k.db'));
      expect(s.state, LinkState.invalid);
      expect(s.message, contains('chunks_fts'));
    });

    test('version de esquema no soportada', () {
      createDb(path('k.db'), version: '99');
      final s = ExternalFileValidator.validateKnowledgeSync(path('k.db'));
      expect(s.state, LinkState.invalid);
      expect(s.schemaVersion, '99');
    });

    test('un archivo que no es SQLite es invalido', () {
      File(path('k.db')).writeAsStringSync('no soy sqlite' * 20);
      expect(
        ExternalFileValidator.validateKnowledgeSync(path('k.db')).state,
        LinkState.invalid,
      );
    });

    test('inexistente es missing', () {
      expect(
        ExternalFileValidator.validateKnowledgeSync(path('no.db')).state,
        LinkState.missing,
      );
    });
  });
}
