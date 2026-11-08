import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inocencia/core/di/providers.dart';
import 'package:inocencia/core/storage/platform_info.dart';
import 'package:inocencia/features/external_data/domain/external_files_repository.dart';
import 'package:inocencia/features/external_data/domain/linked_file_status.dart';
import 'package:inocencia/features/tutor/application/speed_test_controller.dart';
import 'package:inocencia/features/tutor/domain/speed_test.dart';
import 'package:inocencia/features/tutor/domain/tutor_diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';

SpeedSample gen(int threads, double tps) =>
    SpeedSample(kind: SpeedKind.generation, threads: threads, tokens: 32, millis: (32000 / tps).round());

SpeedSample read(int threads, double tps) =>
    SpeedSample(kind: SpeedKind.prompt, threads: threads, tokens: 70, millis: (70000 / tps).round());

class _Files implements ExternalFilesRepository {
  _Files({this.ready = true});
  final bool ready;

  @override
  Future<LinkedFilesStatus> check() async => LinkedFilesStatus(
    model: ready
        ? const LinkedFileStatus(state: LinkState.ready, path: '/m.gguf')
        : const LinkedFileStatus(state: LinkState.notLinked),
    knowledge: const KnowledgeDbStatus.notLinked(),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Platform extends PlatformInfo {
  _Platform();
  final screenOn = <bool>[];

  @override
  Future<int?> thermalStatus() async => 0;

  @override
  Future<void> keepScreenOn(bool on) async => screenOn.add(on);
}

/// Motor falso: suelta las muestras cuando la prueba las pide.
class _Tester implements SpeedTester {
  _Tester(this.samples);
  final List<SpeedSample> samples;
  final controller = StreamController<SpeedSample>();
  String? loaded;
  bool disposed = false;

  @override
  Future<void> load(String modelPath) async => loaded = modelPath;

  @override
  Stream<SpeedSample> speedTest(SpeedPlan plan) {
    for (final s in samples) {
      controller.add(s);
    }
    return controller.stream;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeedPlan', () {
    test('8 nucleos: escribir con 2-6 hilos, leer con 4, 6 y 8', () {
      final p = SpeedPlan.forCores(8);
      expect(p.generation, [2, 3, 4, 5, 6]);
      expect(p.prompt, [4, 6, 8]);
      expect(p.steps, 16); // dos pasadas
    });

    test('4 nucleos solo prueba lo que cabe', () {
      final p = SpeedPlan.forCores(4);
      expect(p.generation, [2, 3, 4]);
      expect(p.prompt, [4]);
    });
  });

  group('SpeedTestResult', () {
    test('elige lo mas rapido; un empate (< 5 %) se queda con menos hilos', () {
      final r = SpeedTestResult(
        samples: [gen(2, 6), gen(3, 9), gen(4, 9.3), gen(5, 4), read(4, 40), read(6, 60), read(8, 20)],
      );
      expect(r.bestGeneration, 3);
      expect(r.bestPrompt, 6);
      expect(r.isComplete, isTrue);
    });

    test('el informe trae la tabla, la mejor combinacion y la temperatura', () {
      final r = SpeedTestResult(samples: [gen(4, 8), read(6, 50)], cpuCompat: true, thermal: 2);
      final text = r.toReport();
      expect(text, contains('CPU en modo compatible'));
      expect(text, contains('caliente'));
      expect(text, contains('4 hilos: 8.0 tokens/s'));
      expect(text, contains('Mejor: 4 hilos al escribir, 6 al leer'));
    });

    test('con dos pasadas se queda con la mejor medida de cada combinacion', () {
      final r = SpeedTestResult(samples: [gen(2, 5), gen(4, 7), gen(4, 9), gen(2, 6), read(4, 30)]);
      expect([for (final s in r.of(SpeedKind.generation)) s.tokensPerSecond.round()], [6, 9]);
      expect(r.bestGeneration, 4);
    });

    test('se guarda y se lee en JSON', () {
      final r = SpeedTestResult(samples: [gen(2, 5), read(4, 30)], cpuCompat: true, thermal: 1);
      expect(SpeedTestResult.fromJson(r.toJson()), r);
    });
  });

  group('diagnostico', () {
    const loaded = TutorDiagnostics(model: 'qwen2.5-3b-instruct-q4_0.gguf', threads: 4, cores: 8);

    test('una respuesta con la app en segundo plano no vale como medida', () {
      final d = loaded.withAnswer(
        firstPieceSeconds: 47,
        pieces: 131,
        totalSeconds: 722,
        piecesPerSecond: 0.2,
        backgrounded: true,
        thermalStart: 0,
        thermalEnd: 1,
      );
      expect(d.verdict(), contains('Medida no válida'));
      final r = d.toReport();
      expect(r, contains('salio de la pantalla'));
      expect(r, contains('Temperatura: normal al empezar, algo caliente al acabar'));
      expect(TutorDiagnostics.fromJson(d.toJson()), d);
    });

    test('lento y caliente: culpa al calor; lento sin mas: propone la prueba', () {
      final hot = loaded.withAnswer(
        firstPieceSeconds: 10,
        pieces: 100,
        totalSeconds: 60,
        piecesPerSecond: 1.5,
        thermalEnd: 3,
      );
      expect(hot.verdict(), contains('caliente'));
      final slow = loaded.withAnswer(firstPieceSeconds: 10, pieces: 100, totalSeconds: 60, piecesPerSecond: 1.5);
      expect(slow.verdict(), contains('prueba de velocidad'));
    });

    test('dice si los hilos vienen de la prueba y si la CPU va en modo compatible', () {
      const d = TutorDiagnostics(
        model: 'm.gguf',
        threads: 3,
        batchThreads: 6,
        cores: 8,
        threadsTuned: true,
        cpuCompat: true,
      );
      expect(d.toReport(), contains('elegidos por la prueba de velocidad'));
      expect(d.toReport(), contains('CPU en modo compatible: si'));
    });
  });

  group('SpeedTestController', () {
    late _Platform platform;

    Future<ProviderContainer> make(_Tester tester, {bool ready = true}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      platform = _Platform();
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          externalFilesRepositoryProvider.overrideWithValue(_Files(ready: ready)),
          speedTesterFactoryProvider.overrideWithValue(() => tester),
          speedPlanProvider.overrideWithValue(SpeedPlan.forCores(8)),
          platformInfoProvider.overrideWithValue(platform),
          cpuCompatActiveProvider.overrideWithValue(false),
        ],
      );
      addTearDown(c.dispose);
      c.listen(speedTestProvider, (_, _) {});
      return c;
    }

    test('mide, guarda la mejor combinacion y libera el modelo', () async {
      final tester = _Tester([gen(2, 5), gen(4, 9), read(4, 40), read(6, 55)]);
      final c = await make(tester);
      await c.read(speedTestProvider.notifier).run();
      expect(tester.loaded, '/m.gguf');
      await pumpEventQueue();
      expect(c.read(speedTestProvider).phase, SpeedPhase.running);
      expect(c.read(speedTestProvider).samples, hasLength(4));
      await tester.controller.close();
      await pumpEventQueue();

      final view = c.read(speedTestProvider);
      expect(view.phase, SpeedPhase.done);
      expect(view.result!.thermal, 0);
      expect(c.read(tutorTuningProvider).threads, const ThreadOverride(generation: 4, prompt: 6));
      expect(tester.disposed, isTrue);
      expect(platform.screenOn, [true, false]);

      // Sobrevive a reiniciar la app.
      final prefs = c.read(sharedPreferencesProvider);
      expect(prefs.getString('tutor_threads'), '4,6');
      expect(prefs.getString('tutor_speed_test'), isNotNull);

      c.read(speedTestProvider.notifier).reset();
      expect(c.read(tutorTuningProvider).threads, isNull);
      expect(prefs.getString('tutor_threads'), isNull);
    });

    test('si la app sale de la pantalla, la prueba se para sin guardar nada', () async {
      final tester = _Tester([gen(2, 5)]);
      final c = await make(tester);
      await c.read(speedTestProvider.notifier).run();
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await pumpEventQueue();
      final view = c.read(speedTestProvider);
      expect(view.phase, SpeedPhase.failed);
      expect(view.message, contains('salió de la pantalla'));
      expect(c.read(tutorTuningProvider).threads, isNull);
      expect(tester.disposed, isTrue);
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    test('sin modelo vinculado lo explica', () async {
      final c = await make(_Tester(const []), ready: false);
      await c.read(speedTestProvider.notifier).run();
      expect(c.read(speedTestProvider).phase, SpeedPhase.failed);
      expect(c.read(speedTestProvider).message, contains('vincula el modelo'));
    });

    test('el modo compatible se guarda en el telefono', () async {
      final c = await make(_Tester(const []));
      c.read(tutorTuningProvider.notifier).setCpuCompat(true);
      expect(c.read(sharedPreferencesProvider).getBool('tutor_cpu_compat'), isTrue);
      expect(c.read(tutorTuningProvider).cpuCompat, isTrue);
    });
  });
}
