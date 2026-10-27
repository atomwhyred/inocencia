import 'child_profile.dart';

abstract class ChildProfileRepository {
  Stream<List<ChildProfile>> watchAll();
  Future<ChildProfile?> getById(int id);
  Future<int> create(ChildProfileInput input, {String? pin});
  Future<void> update(int id, ChildProfileInput input, ChildPinChange pin);
  Future<void> delete(int id);

  /// Comprueba el PIN del nino (true si coincide).
  Future<bool> verifyPin(int id, String pin);
}
