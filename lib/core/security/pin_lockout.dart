import 'package:shared_preferences/shared_preferences.dart';

/// Bloqueo temporal tras intentos fallidos de PIN. Persistente: reiniciar la
/// app no reinicia el contador.
///
/// Además de la hora del teléfono se mide con [uptime], el tiempo desde que se
/// encendió el teléfono, que no se puede cambiar en Ajustes: adelantar el reloj ya
/// no quita el bloqueo. Si el teléfono se reinicia, el bloqueo cuenta de nuevo desde
/// el encendido (nunca dura menos de lo que tocaba).
class PinLockout {
  PinLockout(this._prefs, this.scope, {this.uptime});

  final SharedPreferences _prefs;
  final String scope;
  final Duration Function()? uptime;

  static const maxFreeAttempts = 5;

  String get _failKey => 'pin_fail_$scope';
  String get _untilKey => 'pin_lock_until_$scope';
  String get _startUptimeKey => 'pin_lock_uptime_$scope';
  String get _lengthKey => 'pin_lock_ms_$scope';

  /// Tiempo restante de bloqueo, o null si se puede intentar.
  Duration? remaining(DateTime now) {
    final until = _prefs.getInt(_untilKey);
    if (until == null) return null;
    final length = Duration(milliseconds: _prefs.getInt(_lengthKey) ?? 900000);
    var left = DateTime.fromMillisecondsSinceEpoch(until).difference(now);
    // Atrasar el reloj tampoco alarga el bloqueo más de lo que tocaba.
    if (left > length) left = length;
    final start = _prefs.getInt(_startUptimeKey);
    final up0 = uptime?.call();
    if (start != null && up0 != null) {
      final up = up0.inMilliseconds;
      // Si el tiempo desde el encendido es menor que al bloquear, el teléfono se reinició.
      final elapsed = Duration(milliseconds: up >= start ? up - start : up);
      final byUptime = length - elapsed;
      if (byUptime > left) left = byUptime;
    }
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
      await _prefs.setInt(_lengthKey, seconds * 1000);
      final up0 = uptime?.call();
      if (up0 != null) {
        await _prefs.setInt(_startUptimeKey, up0.inMilliseconds);
      } else {
        await _prefs.remove(_startUptimeKey);
      }
    }
  }

  Future<void> reset() async {
    await _prefs.remove(_failKey);
    await _prefs.remove(_untilKey);
    await _prefs.remove(_startUptimeKey);
    await _prefs.remove(_lengthKey);
  }
}
