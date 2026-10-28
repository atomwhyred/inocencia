import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/storage/app_database.dart';
import '../domain/tutor_history_repository.dart';
import '../domain/tutor_source.dart';

class TutorHistoryRepositoryImpl implements TutorHistoryRepository {
  TutorHistoryRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<List<StoredTutorMessage>> load(int childId, {int limit = 200}) async {
    // Los ultimos `limit` (mas recientes primero) y luego se invierten.
    final rows = await (_db.select(_db.tutorMessages)
          ..where((t) => t.childId.equals(childId))
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(limit))
        .get();
    return rows.reversed.map(_toEntity).toList();
  }

  @override
  Future<void> add(int childId, StoredTutorMessage message) async {
    await _db.into(_db.tutorMessages).insert(
          TutorMessagesCompanion.insert(
            childId: childId,
            fromUser: message.fromUser,
            content: message.text,
            sources: Value(_encodeSources(message.sources)),
          ),
        );
  }

  @override
  Future<void> clear(int childId) =>
      (_db.delete(_db.tutorMessages)..where((t) => t.childId.equals(childId))).go();

  @override
  Future<int> count(int childId) async {
    final n = _db.tutorMessages.id.count();
    final q = _db.selectOnly(_db.tutorMessages)
      ..addColumns([n])
      ..where(_db.tutorMessages.childId.equals(childId));
    return (await q.getSingle()).read(n) ?? 0;
  }

  StoredTutorMessage _toEntity(TutorMessageRow r) => StoredTutorMessage(
        fromUser: r.fromUser,
        text: r.content,
        sources: _decodeSources(r.sources),
        createdAt: r.createdAt,
      );

  static String _encodeSources(List<TutorSource> sources) =>
      jsonEncode([for (final s in sources) s.toJson()]);

  /// Un JSON roto no debe impedir abrir la conversacion: se pierden las fuentes.
  static List<TutorSource> _decodeSources(String raw) {
    try {
      final list = jsonDecode(raw) as List<Object?>;
      return [
        for (final e in list) TutorSource.fromJson((e as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return const [];
    }
  }
}
