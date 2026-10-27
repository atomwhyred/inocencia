import 'package:drift/drift.dart';

import '../../../core/security/pin_hasher.dart';
import '../../../core/storage/app_database.dart';
import '../domain/child_profile.dart';
import '../domain/child_profile_repository.dart';

class ChildProfileRepositoryImpl implements ChildProfileRepository {
  ChildProfileRepositoryImpl(this._db, this._hasher);

  final AppDatabase _db;
  final PinHasher _hasher;

  ChildProfile _toEntity(ChildProfileRow r) => ChildProfile(
        id: r.id,
        name: r.name,
        avatar: r.avatar,
        birthDate: r.birthDate,
        gradeOverride: r.gradeOverride,
        pinLength: r.pinHash == null ? null : r.pinLength,
      );

  @override
  Stream<List<ChildProfile>> watchAll() {
    final q = _db.select(_db.childProfiles)
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);
    return q.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<ChildProfile?> getById(int id) async {
    final row = await (_db.select(_db.childProfiles)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<int> create(ChildProfileInput input, {String? pin}) async {
    final hash = pin == null ? null : await _hasher.hash(pin);
    return _db.into(_db.childProfiles).insert(
          ChildProfilesCompanion.insert(
            name: input.name.trim(),
            avatar: input.avatar,
            birthDate: input.birthDate,
            gradeOverride: Value(input.gradeOverride),
            pinHash: Value(hash),
            pinLength: Value(pin?.length),
          ),
        );
  }

  @override
  Future<void> update(int id, ChildProfileInput input, ChildPinChange pin) async {
    final base = ChildProfilesCompanion(
      name: Value(input.name.trim()),
      avatar: Value(input.avatar),
      birthDate: Value(input.birthDate),
      gradeOverride: Value(input.gradeOverride),
    );
    final companion = switch (pin) {
      KeepChildPin() => base,
      RemoveChildPin() => base.copyWith(
          pinHash: const Value(null),
          pinLength: const Value(null),
        ),
      SetChildPin(:final pin) => base.copyWith(
          pinHash: Value(await _hasher.hash(pin)),
          pinLength: Value(pin.length),
        ),
    };
    await (_db.update(_db.childProfiles)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.childProfiles)..where((t) => t.id.equals(id))).go();

  @override
  Future<bool> verifyPin(int id, String pin) async {
    final row = await (_db.select(_db.childProfiles)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    final stored = row?.pinHash;
    if (stored == null) return true;
    return _hasher.verify(pin, stored);
  }
}
