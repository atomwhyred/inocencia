import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_info.dart';

/// Lo que hace falta de la plataforma (se sustituye en las pruebas).
abstract class TutorWorkPlatform {
  Future<bool> start();
  Future<void> stop({required bool notifyDone});
}

class _AndroidTutorWork implements TutorWorkPlatform {
  const _AndroidTutorWork();

  @override
  Future<bool> start() => const PlatformInfo().startTutorWork();

  @override
  Future<void> stop({required bool notifyDone}) =>
      const PlatformInfo().stopTutorWork(notifyDone: notifyDone);
}

/// Mantiene el servicio en primer plano mientras el modelo trabaja, para que Android no
/// frene la app si el niño sale de ella o apaga la pantalla.
///
/// Cuenta los trabajos en curso (tutor, tarjetas y quiz pueden solaparse) y, al terminar
/// el último, espera [grace] antes de parar el servicio: las tarjetas y el quiz encadenan
/// varias generaciones, y Android 12+ no deja volver a arrancarlo con la app en segundo
/// plano.
class BackgroundWork {
  BackgroundWork({
    TutorWorkPlatform? platform,
    bool Function()? isForeground,
    this.grace = const Duration(seconds: 4),
  }) : _platform = platform ?? const _AndroidTutorWork(),
       _isForeground = isForeground ?? _appVisible;

  final TutorWorkPlatform _platform;
  final bool Function() _isForeground;
  final Duration grace;

  int _active = 0;
  bool _running = false;
  Timer? _stopTimer;

  /// Si hay algún trabajo en curso (para pruebas y diagnósticos).
  bool get running => _running;

  static bool _appVisible() {
    final s = WidgetsBinding.instance.lifecycleState;
    return s == null || s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;
  }

  /// Empieza un trabajo. Arranca el servicio si no estaba en marcha.
  Future<void> begin() async {
    _active++;
    _stopTimer?.cancel();
    _stopTimer = null;
    if (_running) return;
    _running = true;
    try {
      // Si Android no lo deja (la app ya no estaba en pantalla), se sigue sin servicio.
      _running = await _platform.start();
    } catch (_) {
      _running = false;
    }
  }

  /// Termina un trabajo. Con [produced], si la app no está en pantalla se avisa al
  /// parar el servicio de que Toco ya terminó.
  void end({bool produced = true}) {
    if (_active == 0) return;
    _active--;
    if (_active > 0) return;
    _stopTimer?.cancel();
    _stopTimer = Timer(grace, () {
      _stopTimer = null;
      if (_active > 0 || !_running) return;
      _running = false;
      unawaited(_platform.stop(notifyDone: produced && !_isForeground()).catchError((_) {}));
    });
  }

  void dispose() {
    _stopTimer?.cancel();
    if (_running) {
      _running = false;
      unawaited(_platform.stop(notifyDone: false).catchError((_) {}));
    }
  }
}

/// Uno para toda la app: el servicio es único.
final backgroundWorkProvider = Provider<BackgroundWork>((ref) {
  final work = BackgroundWork();
  ref.onDispose(work.dispose);
  return work;
});
