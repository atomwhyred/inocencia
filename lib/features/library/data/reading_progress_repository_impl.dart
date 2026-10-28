import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/reading_progress_repository.dart';

class ReadingProgressRepositoryImpl implements ReadingProgressRepository {
  ReadingProgressRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<int?> get(int childId, String book) async {
    final row = await (_db.select(_db.readingProgress)
          ..where((t) => t.childId.equals(childId) & t.book.equals(book)))
        .getSingleOrNull();
    return row?.page;
  }

  @override
  Future<void> save(int childId, String book, int page) {
    if (page < 1) return Future.value();
    // Una fila por (nino, libro): se actualiza si ya existe.
    return _db.into(_db.readingProgress).insert(
          ReadingProgressCompanion.insert(childId: childId, book: book, page: page),
          onConflict: DoUpdate(
            (old) => ReadingProgressCompanion(page: Value(page), updatedAt: Value(DateTime.now())),
            target: [_db.readingProgress.childId, _db.readingProgress.book],
          ),
        );
  }

  @override
  Future<Map<String, int>> all(int childId) async {
    final rows = await (_db.select(_db.readingProgress)
          ..where((t) => t.childId.equals(childId)))
        .get();
    return {for (final r in rows) r.book: r.page};
  }
}
