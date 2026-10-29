import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../auth/application/session.dart';

/// Si el padre quiere el "Pomodoro infantil": estudiar un rato y descansar.
/// Viene activado.
class PomodoroEnabledController extends Notifier<bool> {
  static const _key = 'pomodoro_enabled';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  Future<void> set(bool value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setBool(_key, value);
  }
}

final pomodoroEnabledProvider = NotifierProvider<PomodoroEnabledController, bool>(
  PomodoroEnabledController.new,
);

/// Cada cuanto se mira el reloj mientras el chat esta abierto. `null` en las
/// pruebas: un `Timer` periodico quedaria pendiente.
final pomodoroTickProvider = Provider<Duration?>((ref) => const Duration(seconds: 1));

/// Cuanto estudia y cuanto descansa un nino segun su grado.
class PomodoroPlan extends Equatable {
  const PomodoroPlan({required this.study, required this.rest});

  /// 1.º a 3.º (y preescolar): 15 + 5 min. 4.º a 6.º: 20 + 5 min.
  factory PomodoroPlan.forGrade(int grade) => PomodoroPlan(
    study: Duration(minutes: grade <= 3 ? 15 : 20),
    rest: const Duration(minutes: 5),
  );

  final Duration study;
  final Duration rest;

  @override
  List<Object?> get props => [study, rest];
}

enum PomodoroPhase { study, rest }

class PomodoroState extends Equatable {
  const PomodoroState({
    this.phase = PomodoroPhase.study,
    this.studied = Duration.zero,
    this.restEnd,
    this.restLeft = Duration.zero,
  });

  final PomodoroPhase phase;

  /// Tiempo estudiado en este bloque (solo cuenta con el chat abierto).
  final Duration studied;

  /// Momento en que acaba el descanso (reloj de pared: salir del chat no lo salta).
  final DateTime? restEnd;
  final Duration restLeft;

  bool get resting => phase == PomodoroPhase.rest;

  /// El descanso acabo, pero el nino aun no ha tocado a Toco para seguir.
  bool get restOver => resting && restLeft <= Duration.zero;

  @override
  List<Object?> get props => [phase, studied, restEnd, restLeft];
}

class PomodoroController extends Notifier<PomodoroState> {
  /// Instante del ultimo reloj; `null` si el chat esta cerrado o en segundo plano.
  DateTime? _last;

  /// Un salto mayor (el telefono durmio) no cuenta como estudio.
  static const _maxStep = Duration(seconds: 5);

  DateTime _now() => ref.read(clockProvider)();

  @override
  PomodoroState build() {
    // Cada nino empieza su propio bloque.
    ref.watch(sessionProvider.select((s) => s.activeChildId));
    _last = null;
    return const PomodoroState();
  }

  /// El chat se abre o vuelve a primer plano: el tiempo de estudio corre.
  void resume() => _last = _now();

  /// El chat se cierra o la app pasa a segundo plano.
  void pause() {
    _accumulate();
    _last = null;
  }

  void _accumulate() {
    final last = _last;
    if (last == null || state.resting) return;
    final now = _now();
    final step = now.difference(last);
    _last = now;
    if (step <= Duration.zero) return;
    state = PomodoroState(studied: state.studied + (step > _maxStep ? _maxStep : step));
  }

  /// Avanza el reloj. [busy]: el tutor esta contestando; no se corta a mitad.
  void tick(PomodoroPlan plan, {bool busy = false}) {
    final now = _now();
    if (state.resting) {
      final end = state.restEnd!;
      final left = end.isAfter(now) ? end.difference(now) : Duration.zero;
      if (left != state.restLeft) {
        state = PomodoroState(phase: PomodoroPhase.rest, restEnd: end, restLeft: left);
      }
      return;
    }
    _accumulate();
    if (_last != null && state.studied >= plan.study && !busy) {
      state = PomodoroState(
        phase: PomodoroPhase.rest,
        restEnd: now.add(plan.rest),
        restLeft: plan.rest,
      );
    }
  }

  /// Toco invita a seguir: solo vale cuando el descanso acabo.
  void finishRest() {
    if (!state.restOver) return;
    state = const PomodoroState();
    _last = _now();
  }
}

final pomodoroProvider = NotifierProvider<PomodoroController, PomodoroState>(
  PomodoroController.new,
);

/// El chat esta congelado: el nino descansa.
final chatFrozenProvider = Provider<bool>((ref) {
  return ref.watch(pomodoroEnabledProvider) && ref.watch(pomodoroProvider).resting;
});
