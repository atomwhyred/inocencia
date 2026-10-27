import 'package:shared_preferences/shared_preferences.dart';

/// Bloqueo temporal tras intentos fallidos de PIN. Persistente: reiniciar la
/// app no reinicia el contador.
class PinLockout {
  PinLockout(this._prefs, this.scope);

  final SharedPreferences _prefs;
  final String scope;

  static const maxFreeAttempts = 5;

  String get _failKey => 'pin_fail_$scope';
  String get _untilKey => 'pin_lock_until_$scope';

  /// Tiempo restante de bloqueo, o null si se puede intentar.
  Duration? remaining(DateTime now) {
    final until = _prefs.getInt(_untilKey);
    if (until == null) return null;
    final left = DateTime.fromMillisecondsSinceEpoch(until).difference(now);
    return left > Duration.zero ? left : null;
  }

  Future<void> registerFailure(DateTime now) async {
    final fails = (_prefs.getInt(_failKey) ?? 0) + 1;
    await _prefs.setInt(_failKey, fails);
    if (fails % maxFreeAttempts == 0) {
      // 30 s, 1 min, 2 min... con tope de 15 min.
      final step = (fails ~/ maxFreeAttempts) - 1;
      final seconds = (30 * (1 << step.clamp(0, 5))).clamp(30, 900);
      await _prefs.setInt(
        _untilKey,
        now.add(Duration(seconds: seconds)).millisecondsSinceEpoch,
      );
    }
  }

  Future<void> reset() async {
    await _prefs.remove(_failKey);
    await _prefs.remove(_untilKey);
  }
}
