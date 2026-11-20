import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../core/storage/untrusted_db.dart';

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
    final books = [for (final m in inGrade) _toBook(m, inGrade, pdfs[m.id.toLowerCase()])];
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
    return _toBook(meta, siblings, (await _findPdfs())[id.toLowerCase()]);
  }

  @override
  Future<LibraryStatus> status() async {
    final all = _readCatalog();
    final pdfs = await _findPdfs();
    final grades = {for (final m in all) ...m.grades};
    return LibraryStatus(
      total: all.length,
      available: all.where((m) => pdfs.containsKey(m.id.toLowerCase())).length,
      folders: [for (final root in await _files.appStorageDirs()) p.join(root, folderName)],
      linkedFolder: _files.booksFolder,
      byGrade: {
        for (final g in grades)
          g: () {
            final inGrade = all.where((m) => m.grades.contains(g));
            return GradeBooks(
              total: inGrade.length,
              available: inGrade.where((m) => pdfs.containsKey(m.id.toLowerCase())).length,
            );
          }(),
      },
    );
  }

  @override
  Future<List<BookFolder>> findBookFolders() async {
    final ids = {for (final m in _readCatalog()) m.id.toLowerCase()};
    if (ids.isEmpty) return const [];
    final browse = await _files.browseRoots();
    // Las carpetas de la app ya se leen solas: no hace falta vincularlas.
    final appDirs = await _files.appStorageDirs();
    final roots = <String>{
      ...browse,
      for (final r in browse)
        for (final sub in const ['Download', 'Documents', 'Books']) p.join(r, sub),
    };
    // Un conjunto de rutas: Download se recorre desde la raiz y por si solo.
    final files = <String>{};
    for (final root in roots) {
      await for (final f in _pdfsIn(root, depth: _searchDepth)) {
        if (ids.contains(p.basenameWithoutExtension(f.path).toLowerCase())) files.add(f.path);
      }
    }
    final own = <String, int>{};
    for (final f in files) {
      own[p.dirname(f)] = (own[p.dirname(f)] ?? 0) + 1;
    }
    // Candidatas: las carpetas con PDF y su carpeta madre (por si estan repartidos
    // en subcarpetas por grado). Cada una cuenta los PDF de todo lo que contiene.
    final candidates = <String>{
      ...own.keys,
      for (final d in own.keys)
        if (!browse.contains(p.dirname(d)) && p.dirname(d) != d) p.dirname(d),
    };
    final all = [
      for (final c in candidates)
        if (!appDirs.any((a) => c == a || p.isWithin(a, c)))
          BookFolder(
            path: c,
            count: files.where((f) => p.isWithin(c, f)).length,
          ),
    ];
    // Entre una carpeta y su madre se ofrece la madre solo si trae mas libros.
    final result = [
      for (final c in all)
        if (!all.any((d) =>
            d.path != c.path &&
            ((p.isWithin(c.path, d.path) && d.count == c.count) ||
                (p.isWithin(d.path, c.path) && d.count > c.count))))
          c,
    ]..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.path.length.compareTo(b.path.length);
      });
    return result;
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
    final db = openUntrustedDb(path);
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

  /// Cuanto se baja buscando PDF en una carpeta vinculada o al detectar.
  static const _searchDepth = 3;

  /// `id -> ruta` de los PDF que ya estan en el telefono. Gana la carpeta que el
  /// padre vinculo, luego `libros/` de la app y por ultimo la carpeta de la app.
  /// Las claves van en minusculas: `6TO_ESP.pdf` vale para el libro `6to_esp`.
  Future<Map<String, String>> _findPdfs() async {
    final found = <String, String>{};
    final linked = _files.booksFolder;
    final dirs = <(String, int)>[
      if (linked != null) (linked, _searchDepth),
      for (final root in await _files.appStorageDirs()) ...[
        (p.join(root, folderName), 0),
        (root, 0),
      ],
    ];
    for (final (dir, depth) in dirs) {
      await for (final e in _pdfsIn(dir, depth: depth)) {
        found.putIfAbsent(p.basenameWithoutExtension(e.path).toLowerCase(), () => e.path);
      }
    }
    return found;
  }

  /// Los `.pdf` de [dir] y, hasta [depth] niveles, de sus subcarpetas. Ignora
  /// carpetas ocultas y `Android/` (datos de otras apps, no se pueden leer).
  Stream<File> _pdfsIn(String dir, {required int depth}) async* {
    List<FileSystemEntity> entries;
    try {
      entries = await Directory(dir).list(followLinks: false).toList();
    } on FileSystemException {
      return; // Carpeta inexistente, sin permiso o volumen extraido (SD).
    }
    for (final e in entries) {
      final name = p.basename(e.path);
      if (e is File) {
        if (p.extension(name).toLowerCase() == '.pdf') yield e;
      } else if (e is Directory && depth > 0 && !name.startsWith('.') && name != 'Android') {
        yield* _pdfsIn(e.path, depth: depth - 1);
      }
    }
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
