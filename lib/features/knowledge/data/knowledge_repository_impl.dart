import 'package:sqlite3/sqlite3.dart';

import '../domain/knowledge_chunk.dart';
import 'fts_query.dart';

/// Lee el `knowledge.db` (solo lectura) y recupera fragmentos con FTS5 + BM25.
/// Cada consulta pide `grade = ?`: nunca se mezclan libros de otros grados.
class KnowledgeRepositoryImpl implements KnowledgeRepository {
  KnowledgeRepositoryImpl.open(String path)
      : _db = sqlite3.open(path, mode: OpenMode.readOnly);

  final Database _db;

  /// Con menos resultados que esto, la consulta estricta (AND) se amplia a OR.
  static const _enough = 2;

  static const _sql = '''
SELECT c.id, c.grade, c.subject, c.book, c.chapter, c.page, c.text
FROM chunks_fts
JOIN chunks c ON c.id = chunks_fts.rowid
WHERE chunks_fts MATCH ?1 AND c.grade = ?2 AND (?3 IS NULL OR c.subject = ?3)
ORDER BY bm25(chunks_fts)
LIMIT ?4
''';

  List<KnowledgeChunk> _run(String match, int grade, String? subject, int limit) {
    if (match.isEmpty) return const [];
    try {
      return _db
          .select(_sql, [match, grade, subject, limit])
          .map((r) => KnowledgeChunk(
                id: r['id'] as int,
                grade: r['grade'] as int,
                subject: r['subject'] as String,
                book: r['book'] as String?,
                chapter: r['chapter'] as String?,
                page: r['page'] as int?,
                text: r['text'] as String,
              ))
          .toList();
    } on SqliteException {
      return const []; // consulta mal formada: se trata como "sin resultados"
    }
  }

  @override
  Future<List<KnowledgeChunk>> search(
    String question, {
    required int grade,
    String? subject,
    int limit = 3,
  }) async {
    final strict = _run(ftsAllQuery(question), grade, subject, limit);
    if (strict.length >= _enough) return strict;
    final loose = _run(ftsAnyQuery(question), grade, subject, limit);
    // Lo estricto va primero: es lo mas especifico; se completa con lo amplio.
    final seen = strict.map((c) => c.id).toSet();
    return [
      ...strict,
      ...loose.where((c) => !seen.contains(c.id)),
    ].take(limit).toList();
  }

  @override
  Future<List<String>> subjectsForGrade(int grade) async => _db
      .select('SELECT DISTINCT subject FROM chunks WHERE grade = ? ORDER BY subject', [grade])
      .map((r) => r['subject'] as String)
      .toList();

  @override
  Future<void> close() async => _db.close();
}
