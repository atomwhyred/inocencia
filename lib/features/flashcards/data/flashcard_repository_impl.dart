import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/flashcard.dart';
import '../domain/flashcard_repository.dart';

class FlashcardRepositoryImpl implements FlashcardRepository {
  FlashcardRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Flashcard>> watchDeck(int childId) {
    final query = _db.select(_db.flashcards)
      ..where((f) => f.childId.equals(childId))
      ..orderBy([(f) => OrderingTerm.desc(f.createdAt), (f) => OrderingTerm.desc(f.id)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          Flashcard(
            id: r.id,
            front: r.front,
            back: r.back,
            source: r.source,
            timesKnown: r.timesKnown,
            timesReviewed: r.timesReviewed,
          ),
      ],
    );
  }

  @override
  Future<int> addAll(int childId, List<FlashcardDraft> drafts, DateTime at) {
    return _db.transaction(() async {
      var added = 0;
      for (final d in drafts) {
        final exists = await (_db.select(
          _db.flashcards,
        )..where((f) => f.childId.equals(childId) & f.front.equals(d.front))).getSingleOrNull();
        if (exists != null) continue;
        await _db
            .into(_db.flashcards)
            .insert(
              FlashcardsCompanion.insert(
                childId: childId,
                front: d.front,
                back: d.back,
                source: Value(d.source),
                createdAt: Value(at),
              ),
            );
        added++;
      }
      return added;
    });
  }

  @override
  Future<void> markReviewed(int id, {required bool known, required DateTime at}) async {
    await _db.customUpdate(
      'UPDATE flashcards SET times_reviewed = times_reviewed + 1, '
      'times_known = times_known + ?, last_reviewed_at = ? WHERE id = ?',
      variables: [Variable.withInt(known ? 1 : 0), Variable.withDateTime(at), Variable.withInt(id)],
      updates: {_db.flashcards},
    );
  }

  @override
  Future<void> delete(int id) async {
    await (_db.delete(_db.flashcards)..where((f) => f.id.equals(id))).go();
  }
}
