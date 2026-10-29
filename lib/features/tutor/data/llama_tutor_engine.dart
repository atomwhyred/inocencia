import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../domain/cpu_threads.dart';
import '../domain/tutor_engine.dart';
import 'llama_worker.dart';
import 'native_backends.dart';
import '../domain/tutor_prompt.dart';

/// Motor local con llama.cpp (via `llama_cpp_dart`). El modelo vive en un
/// isolate propio ([LlamaWorker]): la interfaz nunca se bloquea mientras genera.
///
/// Solo CPU (`nGpuLayers = 0`): es lo mas estable en moviles de gama baja.
class LlamaTutorEngine implements TutorEngine {
  /// [nativeLibraryDir] resuelve la carpeta de las `.so` de la app, donde estan
  /// las variantes de CPU de llama.cpp.
  LlamaTutorEngine({this.nativeLibraryDir});

  final Future<String?> Function()? nativeLibraryDir;
  LlamaWorker? _worker;

  static const contextTokens = 2048;

  /// Las respuestas son cortas por diseno (~60 palabras): el tope solo evita que
  /// un modelo desbocado alargue la espera.
  static const maxAnswerTokens = 220;

  /// llama_cpp_dart cuenta los tokens generados como `posicion - tokens del
  /// prompt`: con el prefijo ya en la cache salen contados de mas. Este margen
  /// cubre las instrucciones (~220 tokens); el tope real lo aplica el worker
  /// ([maxAnswerTokens]).
  static const _prefixReserve = 300;

  @override
  bool get isLoaded => _worker != null;

  /// Hilos de calculo: los de los nucleos rapidos del chip ([CpuThreads]). Los
  /// pequenos frenarian al conjunto, porque llama.cpp reparte el trabajo a partes iguales.
  /// Con el modo ahorro, dos hilos: la bateria dura mas y el telefono no se calienta.
  static const lowPowerThreads = 2;

  /// Tope de la respuesta en modo ahorro (menos tokens = menos calculo).
  static const lowPowerAnswerTokens = 160;

  bool _lowPower = false;

  static int get threads =>
      CpuThreads.choose(_coreFreqsKhz(), coreCount: Platform.numberOfProcessors);

  /// Frecuencia maxima de cada nucleo (kHz); vacia si Android no deja leerla.
  static List<int> _coreFreqsKhz() {
    final freqs = <int>[];
    try {
      for (var i = 0; i < Platform.numberOfProcessors; i++) {
        final f = File('/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_max_freq');
        if (f.existsSync()) freqs.add(int.tryParse(f.readAsStringSync().trim()) ?? 0);
      }
    } catch (_) {}
    return freqs;
  }

  @override
  Future<void> load(String modelPath, {bool lowPower = false}) async {
    _lowPower = lowPower;
    await dispose();
    if (!File(modelPath).existsSync()) {
      throw const TutorEngineException('No se encuentra el archivo del modelo.');
    }
    // Elige la variante de CPU antes de que el modelo se cargue en su isolate.
    NativeBackends.loadCpuVariant(await nativeLibraryDir?.call());
    final threadCount = lowPower ? lowPowerThreads : threads;
    debugPrint(
      '[tutor] modelo ${modelPath.split('/').last} '
      '(${(File(modelPath).lengthSync() / 1e9).toStringAsFixed(2)} GB), '
      '$threadCount hilos de ${Platform.numberOfProcessors} nucleos '
      '(frecuencias ${_coreFreqsKhz()}), ahorro: $lowPower',
    );
    // Sin GPU. El binding trae por defecto `splitMode = none` con `mainGpu = 0`
    // y llama.cpp rechaza esa combinacion cuando no hay ninguna GPU (devuelve
    // nulo al instante): se usan los valores propios de llama.cpp. Tambien
    // reactiva `useExtraBufts`, que acelera los pesos cuantizados en ARM.
    final model = ModelParams()
      ..nGpuLayers = 0
      ..splitMode = LlamaSplitMode.layer
      ..useExtraBufts = true
      // Sin mmap: el modelo se lee una vez a memoria propia. Con mmap sobre
      // almacenamiento externo (FUSE), el sistema expulsa paginas del modelo
      // cuando hay poca RAM y cada una hay que releerla despacio, con lo que la
      // generacion se arrastra. Es lo que pasa en un movil modesto y cargado.
      ..useMemorymap = false;
    final context = ContextParams()
      ..nCtx = contextTokens
      // El prompt (instrucciones + fragmentos del libro + historial) tiene que
      // caber entero en un lote: con 512 fallaba con ~730 tokens.
      ..nBatch = contextTokens
      ..nUbatch = 512
      ..nThreads = threadCount
      ..nThreadsBatch = threadCount
      ..nPredict = maxAnswerTokens + _prefixReserve;
    // Respuestas fieles al libro: poca aleatoriedad.
    final sampler = SamplerParams()
      ..temp = 0.3
      ..topK = 40
      ..topP = 0.9
      ..penaltyRepeat = 1.1;

    _worker = await LlamaWorker.start(
      WorkerLoad(
        path: modelPath,
        model: model,
        context: context,
        sampler: sampler,
        // En depuracion llama.cpp cuenta por que falla una carga.
        verbose: kDebugMode,
      ),
    );
  }

  @override
  Stream<String> generate(List<ChatTurn> turns, {int? maxTokens}) {
    final worker = _worker;
    if (worker == null) {
      return Stream.error(const TutorEngineException('El modelo no esta cargado.'));
    }
    // El sistema es el prefijo que el worker procesa una vez y reutiliza; lo
    // demas (historial, libro y pregunta) cambia en cada turno.
    final hasSystem = turns.isNotEmpty && turns.first.role == 'system';
    final (id, stream) = worker.generate(
      system: hasSystem ? _chatml(turns.take(1)) : '',
      suffix: '${_chatml(hasSystem ? turns.skip(1) : turns)}<|im_start|>assistant\n',
      maxTokens: maxTokens ?? (_lowPower ? lowPowerAnswerTokens : maxAnswerTokens),
    );
    late final StreamController<String> out;
    StreamSubscription<String>? sub;
    final clock = Stopwatch()..start();
    Duration? firstPiece;
    var pieces = 0;
    void report() {
      if (pieces == 0) return;
      final total = clock.elapsed;
      final rest = total - (firstPiece ?? Duration.zero);
      final rate = rest.inMilliseconds > 0 ? (pieces - 1) * 1000 / rest.inMilliseconds : 0;
      debugPrint(
        '[tutor] primera pieza ${firstPiece?.inSeconds} s, $pieces piezas en '
        '${total.inSeconds} s (${rate.toStringAsFixed(1)} piezas/s tras la primera)',
      );
    }

    out = StreamController<String>(
      onListen: () {
        sub = stream.listen(
          (piece) {
            pieces++;
            firstPiece ??= clock.elapsed;
            final clean = piece.replaceAll('<|im_end|>', '');
            if (clean.isNotEmpty && !out.isClosed) out.add(clean);
          },
          onError: (Object e) {
            if (!out.isClosed) out.addError(e);
          },
          onDone: () {
            report();
            if (!out.isClosed) out.close();
          },
        );
      },
      onCancel: () async {
        // Para la generacion si seguia en marcha y deja de escuchar.
        worker.stop(id);
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  /// ChatML de Qwen2.5: `<|im_start|>rol\ncontenido<|im_end|>\n`. Los turnos del
  /// asistente vacios se omiten.
  static String _chatml(Iterable<ChatTurn> turns) {
    final buf = StringBuffer();
    for (final t in turns) {
      if (t.role == 'assistant' && t.content.isEmpty) continue;
      buf.write('<|im_start|>${t.role}\n${t.content}<|im_end|>\n');
    }
    return buf.toString();
  }

  @override
  Future<void> dispose() async {
    final w = _worker;
    _worker = null;
    if (w != null) {
      try {
        await w.dispose();
      } catch (_) {}
    }
  }
}
