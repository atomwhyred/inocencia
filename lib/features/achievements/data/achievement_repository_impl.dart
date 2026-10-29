import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/achievement.dart';
import '../domain/achievement_repository.dart';

class AchievementRepositoryImpl implements AchievementRepository {
  AchievementRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<bool> award(int childId, String code, DateTime at) {
    return _db.transaction(() async {
      final exists = await (_db.select(_db.achievements)
            ..where((a) => a.childId.equals(childId) & a.code.equals(code)))
          .getSingleOrNull();
      if (exists != null) return false;
      await _db.into(_db.achievements).insert(
            AchievementsCompanion.insert(childId: childId, code: code, earnedAt: Value(at)),
          );
      return true;
    });
  }

  @override
  Future<int> counter(int childId, String name) async {
    final row = await (_db.select(
      _db.childCounters,
    )..where((c) => c.childId.equals(childId) & c.counter.equals(name))).getSingleOrNull();
    return row?.amount ?? 0;
  }

  @override
  Future<void> setCounter(int childId, String name, int value) async {
    await _db
        .into(_db.childCounters)
        .insert(
          ChildCountersCompanion.insert(childId: childId, counter: name, amount: Value(value)),
          onConflict: DoUpdate(
            (_) => ChildCountersCompanion(amount: Value(value)),
            target: [_db.childCounters.childId, _db.childCounters.counter],
          ),
        );
  }

  @override
  Future<int> addToCounter(int childId, String name, int delta) async {
    return _db.transaction(() async {
      final value = await counter(childId, name) + delta;
      await setCounter(childId, name, value);
      return value;
    });
  }

  Future<ChildProgress> _load(int childId) async {
    final rows = await (_db.select(
      _db.achievements,
    )..where((a) => a.childId.equals(childId))).get();
    return ChildProgress(
      earned: {for (final r in rows) r.code: r.earnedAt},
      stars: await counter(childId, Counters.correct),
    );
  }

  @override
  Stream<ChildProgress> watch(int childId) {
    // Vuelve a emitir cuando cambia cualquiera de las dos tablas.
    return _db
        .customSelect('SELECT 1', readsFrom: {_db.achievements, _db.childCounters})
        .watch()
        .asyncMap((_) => _load(childId));
  }
}
