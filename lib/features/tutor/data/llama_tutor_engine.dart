import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../domain/tutor_engine.dart';
import '../domain/tutor_prompt.dart';

/// Motor local con llama.cpp (via `llama_cpp_dart`). El modelo vive en un
/// isolate propio: la interfaz nunca se bloquea mientras genera.
///
/// Solo CPU (`nGpuLayers = 0`): es lo mas estable en moviles de gama baja.
class LlamaTutorEngine implements TutorEngine {
  LlamaParent? _parent;

  static const contextTokens = 2048;
  static const maxAnswerTokens = 400;

  @override
  bool get isLoaded => _parent != null;

  /// Hilos de calculo: la mitad de los nucleos (los grandes) rinden mejor que
  /// usar todos, porque los pequenos frenan al conjunto.
  static int get threads => (Platform.numberOfProcessors / 2).round().clamp(2, 6);

  @override
  Future<void> load(String modelPath) async {
    await dispose();
    if (!File(modelPath).existsSync()) {
      throw const TutorEngineException('No se encuentra el archivo del modelo.');
    }
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
      ..nThreads = threads
      ..nThreadsBatch = threads
      ..nPredict = maxAnswerTokens;
    // Respuestas fieles al libro: poca aleatoriedad.
    final sampler = SamplerParams()
      ..temp = 0.3
      ..topK = 40
      ..topP = 0.9
      ..penaltyRepeat = 1.1;

    final parent = LlamaParent(
      LlamaLoad(
        path: modelPath,
        modelParams: model,
        contextParams: context,
        samplingParams: sampler,
        // En depuracion llama.cpp cuenta por que falla una carga.
        verbose: kDebugMode,
      ),
      ChatMLFormat(), // formato de Qwen2.5
    );
    try {
      await parent.init();
    } catch (e) {
      // dispose() completa con error "Disposed" un completer que ya nadie
      // espera: se captura para que no salga como excepcion sin manejar.
      final disposed = Completer<void>();
      runZonedGuarded(() async {
        await parent.dispose();
        if (!disposed.isCompleted) disposed.complete();
      }, (_, _) {
        if (!disposed.isCompleted) disposed.complete();
      });
      await disposed.future;
      throw TutorEngineException('No se pudo cargar el modelo: $e');
    }
    _parent = parent;
  }

  @override
  Stream<String> generate(List<ChatTurn> turns) {
    final parent = _parent;
    if (parent == null) {
      return Stream.error(const TutorEngineException('El modelo no esta cargado.'));
    }
    late final StreamController<String> out;
    LlamaScope? scope;
    StreamSubscription<String>? textSub;
    StreamSubscription<CompletionEvent>? doneSub;

    Future<void> cleanup() async {
      await textSub?.cancel();
      await doneSub?.cancel();
      final s = scope;
      scope = null;
      if (s != null) {
        // Detiene la generacion si seguia en marcha y libera el contexto.
        try {
          await s.stop();
          await s.dispose();
        } catch (_) {}
      }
    }

    out = StreamController<String>(
      onListen: () async {
        try {
          // Cada pregunta usa un contexto nuevo: no arrastra los textos de
          // libro de la pregunta anterior (el historial va en `turns`).
          parent.messages = [for (final t in turns) t.toMap()];
          // getScope() (no `LlamaScope(parent)`): el padre solo reenvia las
          // respuestas a los scopes registrados en su lista; uno suelto nunca
          // recibe nada y la pregunta se queda esperando para siempre.
          final s = parent.getScope() as LlamaScope;
          scope = s;
          textSub = s.stream.listen((piece) {
            final clean = piece.replaceAll('<|im_end|>', '');
            if (clean.isNotEmpty && !out.isClosed) out.add(clean);
          });
          doneSub = s.completions.listen((e) async {
            if (out.isClosed) return;
            if (!e.success) {
              out.addError(TutorEngineException(e.errorDetails ?? 'La generacion fallo.'));
            }
            await out.close();
          });
          await s.sendPrompt(''); // el texto real sale de parent.messages
        } catch (e) {
          if (!out.isClosed) {
            out.addError(TutorEngineException('$e'));
            await out.close();
          }
        }
      },
      onCancel: cleanup,
    );
    // Al cerrarse el stream por su cuenta tambien se libera.
    out.done.whenComplete(cleanup);
    return out.stream;
  }

  @override
  Future<void> dispose() async {
    final p = _parent;
    _parent = null;
    if (p != null) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}
