import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/features/pomodoro/application/pomodoro.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('15+5 minutos de 1.º a 3.º (y preescolar), 20+5 de 4.º a 6.º', () {
    for (final g in [0, 1, 2, 3]) {
      final p = PomodoroPlan.forGrade(g);
      expect(p.study, const Duration(minutes: 15), reason: 'grado $g');
      expect(p.rest, const Duration(minutes: 5));
    }
    for (final g in [4, 5, 6]) {
      expect(PomodoroPlan.forGrade(g).study, const Duration(minutes: 20), reason: 'grado $g');
      expect(PomodoroPlan.forGrade(g).rest, const Duration(minutes: 5));
    }
  });

  group('PomodoroController', () {
    late DateTime now;
    late ProviderContainer c;
    final plan = PomodoroPlan.forGrade(1);

    PomodoroController ctl() => c.read(pomodoroProvider.notifier);
    PomodoroState st() => c.read(pomodoroProvider);

    /// Avanza el reloj de a 1 s, como el temporizador de la pantalla.
    void advance(Duration d, {bool busy = false}) {
      for (var i = 0; i < d.inSeconds; i++) {
        now = now.add(const Duration(seconds: 1));
        ctl().tick(plan, busy: busy);
      }
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      now = DateTime(2026, 10, 29, 9);
      c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
        clockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(c.dispose);
    });

    test('viene activado y se puede apagar', () async {
      expect(c.read(pomodoroEnabledProvider), isTrue);
      await c.read(pomodoroEnabledProvider.notifier).set(false);
      expect(c.read(pomodoroEnabledProvider), isFalse);
      expect(c.read(chatFrozenProvider), isFalse);
    });

    test('estudia el tiempo del plan y entonces el chat se congela', () {
      ctl().resume();
      advance(const Duration(minutes: 14, seconds: 59));
      expect(st().resting, isFalse);
      expect(c.read(chatFrozenProvider), isFalse);
      advance(const Duration(seconds: 1));
      expect(st().resting, isTrue);
      expect(st().restLeft, const Duration(minutes: 5));
      expect(c.read(chatFrozenProvider), isTrue);
    });

    test('apagado por el padre, nunca se congela', () async {
      await c.read(pomodoroEnabledProvider.notifier).set(false);
      expect(c.read(chatFrozenProvider), isFalse);
    });

    test('no corta una respuesta a medias: espera a que acabe', () {
      ctl().resume();
      advance(const Duration(minutes: 16), busy: true);
      expect(st().resting, isFalse);
      advance(const Duration(seconds: 1));
      expect(st().resting, isTrue);
    });

    test('con el chat cerrado el estudio no cuenta', () {
      ctl().resume();
      advance(const Duration(minutes: 10));
      ctl().pause();
      now = now.add(const Duration(hours: 2));
      ctl().resume();
      advance(const Duration(minutes: 4, seconds: 59));
      expect(st().resting, isFalse);
      advance(const Duration(seconds: 1));
      expect(st().resting, isTrue);
    });

    test('un salto de reloj enorme (el móvil durmió) no cuenta como estudio', () {
      ctl().resume();
      now = now.add(const Duration(hours: 1));
      ctl().tick(plan);
      expect(st().resting, isFalse);
      expect(st().studied, lessThan(const Duration(minutes: 1)));
    });

    test('el descanso cuenta atrás y solo al llegar a cero se puede volver', () {
      ctl().resume();
      advance(const Duration(minutes: 15));
      advance(const Duration(minutes: 4, seconds: 59));
      expect(st().restLeft, const Duration(seconds: 1));
      ctl().finishRest();
      expect(st().resting, isTrue, reason: 'aun no acabó el descanso');

      advance(const Duration(seconds: 1));
      expect(st().restOver, isTrue);
      expect(c.read(chatFrozenProvider), isTrue, reason: 'sigue congelado hasta tocar a Toco');
      ctl().finishRest();
      expect(st().resting, isFalse);
      expect(c.read(chatFrozenProvider), isFalse);
      expect(st().studied, Duration.zero);
    });

    test('salir del chat no salta el descanso', () {
      ctl().resume();
      advance(const Duration(minutes: 15));
      ctl().pause();
      now = now.add(const Duration(minutes: 2));
      ctl().resume();
      ctl().tick(plan);
      expect(st().restLeft, const Duration(minutes: 3));
      expect(st().resting, isTrue);
    });
  });
}
