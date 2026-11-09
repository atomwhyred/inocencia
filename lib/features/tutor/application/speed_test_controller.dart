import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/providers.dart';
import '../../../core/storage/platform_info.dart';
import '../data/llama_tutor_engine.dart';
import '../data/native_backends.dart';
import '../domain/speed_test.dart';

/// Ajustes del tutor para este telefono: hilos elegidos con la prueba y CPU en
/// modo compatible. Se guardan en el telefono.
class TutorTuning extends Equatable {
  const TutorTuning({this.threads, this.cpuCompat = false});

  final ThreadOverride? threads;
  final bool cpuCompat;

  @override
  List<Object?> get props => [threads, cpuCompat];
}

class TutorTuningNotifier extends Notifier<TutorTuning> {
  static const _threadsKey = 'tutor_threads';
  static const _compatKey = 'tutor_cpu_compat';

  SharedPreferences? _prefs;

  @override
  TutorTuning build() {
    try {
      _prefs = ref.read(sharedPreferencesProvider);
    } catch (_) {
      _prefs = null; // en pruebas sin preferencias, solo en memoria
    }
    final parts = _prefs?.getString(_threadsKey)?.split(',');
    final gen = parts?.length == 2 ? int.tryParse(parts![0]) : null;
    final prompt = parts?.length == 2 ? int.tryParse(parts![1]) : null;
    return TutorTuning(
      threads: gen == null || prompt == null ? null : ThreadOverride(generation: gen, prompt: prompt),
      cpuCompat: _prefs?.getBool(_compatKey) ?? false,
    );
  }

  void setThreads(ThreadOverride? t) {
    state = TutorTuning(threads: t, cpuCompat: state.cpuCompat);
    if (t == null) {
      _prefs?.remove(_threadsKey).ignore();
    } else {
      _prefs?.setString(_threadsKey, '${t.generation},${t.prompt}').ignore();
    }
  }

  /// Se aplica al reiniciar la app: la variante de CPU se fija una vez por proceso.
  void setCpuCompat(bool on) {
    state = TutorTuning(threads: state.threads, cpuCompat: on);
    _prefs?.setBool(_compatKey, on).ignore();
  }
}

final tutorTuningProvider = NotifierProvider<TutorTuningNotifier, TutorTuning>(
  TutorTuningNotifier.new,
);

/// Si la CPU se cargo en modo compatible en este arranque de la app.
final cpuCompatActiveProvider = Provider<bool>((ref) => NativeBackends.compat);

/// Motor nuevo para la prueba (se sobrescribe en las pruebas).
final speedTesterFactoryProvider = Provider<SpeedTester Function()>((ref) {
  final compat = ref.read(tutorTuningProvider).cpuCompat;
  return () => LlamaTutorEngine(
    nativeLibraryDir: const PlatformInfo().nativeLibraryDir,
    cpuCompat: compat,
  );
});

final speedPlanProvider = Provider<SpeedPlan>(
  (ref) => SpeedPlan.forCores(Platform.numberOfProcessors),
);

final platformInfoProvider = Provider<PlatformInfo>((ref) => const PlatformInfo());

enum SpeedPhase { idle, loading, running, done, failed }

class SpeedTestView extends Equatable {
  const SpeedTestView({
    this.phase = SpeedPhase.idle,
    this.samples = const [],
    this.steps = 0,
    this.result,
    this.message,
  });

  final SpeedPhase phase;

  /// Medidas de la prueba en curso.
  final List<SpeedSample> samples;
  final int steps;

  /// Ultima prueba terminada (sobrevive a cerrar la app).
  final SpeedTestResult? result;
  final String? message;

  bool get busy => phase == SpeedPhase.loading || phase == SpeedPhase.running;

  @override
  List<Object?> get props => [phase, samples, steps, result, message];
}

/// Prueba de velocidad: carga el modelo, mide varias combinaciones de hilos y se
/// queda con la mas rapida para este telefono.
class SpeedTestController extends Notifier<SpeedTestView> {
  static const _key = 'tutor_speed_test';

  SpeedTester? _engine;
  StreamSubscription<SpeedSample>? _sub;
  AppLifecycleListener? _lifecycle;
  late PlatformInfo _platform;
  String? _model;

  @override
  SpeedTestView build() {
    _platform = ref.read(platformInfoProvider);
    ref.onDispose(() => _stop());
    SpeedTestResult? saved;
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_key);
      if (raw != null) {
        saved = SpeedTestResult.fromJson(jsonDecode(raw) as Map<String, Object?>);
      }
    } catch (_) {}
    return SpeedTestView(result: saved);
  }

  Future<void> run() async {
    if (state.busy) return;
    final plan = ref.read(speedPlanProvider);
    state = SpeedTestView(phase: SpeedPhase.loading, steps: plan.steps, result: state.result);
    final files = await ref.read(externalFilesRepositoryProvider).check();
    if (!ref.mounted) return;
    if (!files.model.isReady) {
      _fail('Primero vincula el modelo del tutor.');
      return;
    }
    // Con la app fuera de la pantalla Android la frena: la medida no valdria.
    try {
      _lifecycle = AppLifecycleListener(
        onStateChange: (s) {
          if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
            _fail('La prueba se paró porque la app salió de la pantalla. Repítela sin salir de la app.');
          }
        },
      );
    } catch (_) {}
    _model = files.model.path!.split(RegExp(r'[/\\]')).last;
    unawaited(_platform.keepScreenOn(true));
    final engine = _engine = ref.read(speedTesterFactoryProvider)();
    try {
      await engine.load(files.model.path!);
    } catch (e) {
      _fail('No se pudo cargar el modelo: $e');
      return;
    }
    if (!ref.mounted || state.phase != SpeedPhase.loading) {
      await _stop();
      return;
    }
    state = SpeedTestView(phase: SpeedPhase.running, steps: plan.steps, result: state.result);
    _sub = engine.speedTest(plan).listen(
      (s) {
        if (state.phase == SpeedPhase.running) {
          state = SpeedTestView(
            phase: SpeedPhase.running,
            steps: state.steps,
            samples: [...state.samples, s],
            result: state.result,
          );
        }
      },
      onError: (Object e) => _fail('La prueba falló: $e'),
      onDone: _finish,
    );
  }

  Future<void> _finish() async {
    if (state.phase != SpeedPhase.running) return;
    final samples = state.samples;
    final thermal = await _platform.thermalStatus();
    if (!ref.mounted) return;
    final result = SpeedTestResult(
      samples: samples,
      cpuCompat: ref.read(cpuCompatActiveProvider),
      thermal: thermal,
      model: _model,
    );
    if (result.isComplete) {
      ref
          .read(tutorTuningProvider.notifier)
          .setThreads(ThreadOverride(generation: result.bestGeneration!, prompt: result.bestPrompt!));
      try {
        ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(result.toJson())).ignore();
      } catch (_) {}
      state = SpeedTestView(phase: SpeedPhase.done, result: result);
    } else {
      state = SpeedTestView(
        phase: SpeedPhase.failed,
        result: state.result,
        message: 'La prueba no terminó.',
      );
    }
    await _stop();
  }

  void _fail(String message) {
    if (!state.busy) return;
    state = SpeedTestView(phase: SpeedPhase.failed, result: state.result, message: message);
    unawaited(_stop());
  }

  /// Vuelve a los hilos automaticos.
  void reset() => ref.read(tutorTuningProvider.notifier).setThreads(null);

  Future<void> _stop() async {
    _lifecycle?.dispose();
    _lifecycle = null;
    final sub = _sub;
    _sub = null;
    final engine = _engine;
    _engine = null;
    await sub?.cancel();
    await engine?.dispose();
    await _platform.keepScreenOn(false);
  }
}

final speedTestProvider = NotifierProvider<SpeedTestController, SpeedTestView>(
  SpeedTestController.new,
);
