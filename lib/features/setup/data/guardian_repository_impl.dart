import '../../../core/security/pin_hasher.dart';
import '../../../core/storage/app_database.dart';
import '../domain/guardian.dart';

class GuardianRepositoryImpl implements GuardianRepository {
  GuardianRepositoryImpl(this._db, this._hasher);

  final AppDatabase _db;
  final PinHasher _hasher;

  @override
  Stream<Guardian?> watch() {
    final q = _db.select(_db.guardians)..limit(1);
    return q.watch().map((rows) {
      if (rows.isEmpty) return null;
      final r = rows.first;
      return Guardian(id: r.id, name: r.name, pinLength: r.pinLength);
    });
  }

  @override
  Future<void> create({required String name, required String pin}) async {
    final hash = await _hasher.hash(pin);
    await _db.transaction(() async {
      // Solo puede existir un administrador.
      final existing = await _db.select(_db.guardians).get();
      if (existing.isNotEmpty) {
        throw StateError('Ya existe un administrador.');
      }
      await _db.into(_db.guardians).insert(
            GuardiansCompanion.insert(
              name: name.trim(),
              pinHash: hash,
              pinLength: pin.length,
            ),
          );
    });
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final row = await (_db.select(_db.guardians)..limit(1)).getSingleOrNull();
    if (row == null) return false;
    return _hasher.verify(pin, row.pinHash);
  }
}
