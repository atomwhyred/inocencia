import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../external_data/domain/external_files_repository.dart';
import '../domain/library_book.dart';
import '../domain/library_repository.dart';

/// Catalogo = los libros que la base de conocimiento dice contener
/// (`meta.books`, o los `book` de `chunks` si falta). Cada uno esta disponible
/// si su PDF esta en `<carpeta de la app>/libros/` (o directamente en la carpeta
/// de la app, junto al modelo y la base).
class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl(this._files);

  final ExternalFilesRepository _files;

  /// Subcarpeta recomendada para los PDF.
  static const folderName = 'libros';

  @override
  Future<List<LibraryBook>> booksForGrade(int grade) async {
    final all = _readCatalog();
    final pdfs = await _findPdfs();
    final inGrade = all.where((m) => m.grades.contains(grade)).toList();
    final books = [for (final m in inGrade) _toBook(m, inGrade, pdfs[m.id])];
    books.sort((a, b) {
      if (a.isNotebook != b.isNotebook) return a.isNotebook ? 1 : -1;
      final bySubject = a.subject.compareTo(b.subject);
      return bySubject != 0 ? bySubject : a.id.compareTo(b.id);
    });
    return books;
  }

  @override
  Future<LibraryBook?> find(String id) async {
    final all = _readCatalog();
    final meta = all.where((m) => m.id == id).firstOrNull;
    if (meta == null) return null;
    final siblings = all.where((m) => m.grades.any(meta.grades.contains)).toList();
    return _toBook(meta, siblings, (await _findPdfs())[id]);
  }

  @override
  Future<LibraryStatus> status() async {
    final all = _readCatalog();
    final pdfs = await _findPdfs();
    return LibraryStatus(
      total: all.length,
      available: all.where((m) => pdfs.containsKey(m.id)).length,
      folders: [for (final root in await _files.appStorageDirs()) p.join(root, folderName)],
    );
  }

  LibraryBook _toBook(_Meta m, List<_Meta> siblings, String? path) {
    // Dos libros de la misma asignatura y tipo en un grado (p. ej. `6to_esp` y
    // `6to_lengua`) se numeran por el orden de su nombre de archivo: el nombre
    // del archivo no dice nada a un nino ("Geografia (ca geografia)").
    final same = [for (final s in siblings) if (s.baseTitle == m.baseTitle) s.id]..sort();
    final title = same.length > 1 ? '${m.baseTitle} ${same.indexOf(m.id) + 1}' : m.baseTitle;
    return LibraryBook(
      id: m.id,
      title: title,
      subject: m.subject,
      kind: m.kind,
      grades: m.grades,
      pages: m.pages,
      path: path,
    );
  }

  List<_Meta> _readCatalog() {
    final path = _files.knowledgePath;
    if (path == null || !File(path).existsSync()) return const [];
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final row = db.select("SELECT value FROM meta WHERE key = 'books'");
      if (row.isNotEmpty) {
        final list = jsonDecode(row.first['value'] as String) as List<Object?>;
        return [
          for (final e in list) _Meta.fromJson((e as Map).cast<String, Object?>()),
        ];
      }
      return _fromChunks(db);
    } catch (_) {
      return const [];
    } finally {
      db.close();
    }
  }

  /// Bases sin `meta.books`: se deduce de los fragmentos.
  List<_Meta> _fromChunks(Database db) {
    final byBook = <String, _Meta>{};
    final rows = db.select(
      'SELECT book, subject, grade, MAX(page) AS pages FROM chunks '
      'WHERE book IS NOT NULL GROUP BY book, subject, grade',
    );
    for (final r in rows) {
      final id = r['book'] as String;
      final prev = byBook[id];
      byBook[id] = _Meta(
        id: id,
        subject: r['subject'] as String,
        kind: _kindFor(id, _guessKind(id)),
        grades: [...?prev?.grades, r['grade'] as int],
        pages: (r['pages'] as int?) ?? prev?.pages ?? 0,
      );
    }
    return byBook.values.toList();
  }

  static String _guessKind(String id) =>
      RegExp(r'(^|_)(ct|cuaderno|workbook|videoclases)(_|$)').hasMatch(id) ? 'Cuaderno' : 'Libro';

  /// `id -> ruta` de los PDF que ya estan en el telefono. Gana `libros/` sobre
  /// la carpeta de la app.
  Future<Map<String, String>> _findPdfs() async {
    final found = <String, String>{};
    for (final root in await _files.appStorageDirs()) {
      for (final dir in [p.join(root, folderName), root]) {
        try {
          await for (final e in Directory(dir).list(followLinks: false)) {
            if (e is! File || p.extension(e.path).toLowerCase() != '.pdf') continue;
            found.putIfAbsent(p.basenameWithoutExtension(e.path), () => e.path);
          }
        } on FileSystemException {
          // Carpeta inexistente o volumen no disponible (SD extraida).
        }
      }
    }
    return found;
  }
}

class _Meta {
  const _Meta({
    required this.id,
    required this.subject,
    required this.kind,
    required this.grades,
    required this.pages,
  });

  factory _Meta.fromJson(Map<String, Object?> j) {
    final id = p.basenameWithoutExtension(j['file'] as String);
    return _Meta(
        id: id,
        subject: j['subject'] as String? ?? '',
        kind: _kindFor(id, j['kind'] as String? ?? 'Libro'),
        grades: [for (final g in (j['grades'] as List<Object?>? ?? const [])) g as int],
        pages: j['pages'] as int? ?? 0,
      );
  }

  final String id;
  final String subject;
  final String kind;
  final List<int> grades;
  final int pages;

  String get baseTitle => kind == 'Cuaderno' ? 'Cuaderno · $subject' : subject;
}

/// Los cuadernos de actividades (`ca_`) tambien se leen como cuadernos, aunque la
/// base los marque como libros.
String _kindFor(String id, String kind) =>
    RegExp(r'(^|_)ca_').hasMatch(id) ? 'Cuaderno' : kind;
