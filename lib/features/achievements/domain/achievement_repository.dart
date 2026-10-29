import 'achievement.dart';

abstract class AchievementRepository {
  /// Da la medalla [code]. `true` si es nueva (no la tenia ya).
  Future<bool> award(int childId, String code, DateTime at);

  Future<int> counter(int childId, String name);

  Future<void> setCounter(int childId, String name, int value);

  /// Suma [delta] y devuelve el valor nuevo.
  Future<int> addToCounter(int childId, String name, int delta);

  /// Medallas y estrellas del nino, al dia mientras cambien.
  Stream<ChildProgress> watch(int childId);
}
