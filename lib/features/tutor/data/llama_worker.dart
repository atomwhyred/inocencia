import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import '../domain/tutor_engine.dart';

/// Lo necesario para cargar el modelo dentro del isolate.
class WorkerLoad {
  const WorkerLoad({
    required this.path,
    required this.model,
    required this.context,
    required this.sampler,
    required this.verbose,
  });

  final String path;
  final ModelParams model;
  final ContextParams context;
  final SamplerParams sampler;
  final bool verbose;
}

/// Isolate propio que posee el modelo de llama.cpp.
///
/// Se usa `Llama` directamente (no `LlamaParent`) porque hace falta lo que el
/// padre no da: procesar el mensaje de sistema **una sola vez** y reutilizarlo
/// en cada turno. Son ~220 de los ~750 tokens del prompt (casi un tercio del
/// tiempo hasta el primer token, y calor que el telefono no necesita).
///
/// El prefijo se procesa con un unico `getNext`: eso decodifica el prompt y
/// muestrea un token que **no** llega a la cache, asi que el estado guardado
/// tiene exactamente los tokens del prefijo. Con `LlamaParent` la parada llegaba
/// decenas de tokens tarde y la cache quedaba con texto inventado.
class LlamaWorker {
  LlamaWorker._(this._isolate, this._toWorker, this._fromWorker);

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;

  final _streams = <int, StreamController<String>>{};

  /// Tokens que el modelo proceso antes de la primera pieza de cada generacion
  /// (el sufijo, mas el prefijo si hubo que construirlo). Para el diagnostico.
  final _promptTokens = <int, int>{};
  Completer<void>? _loading;
  Completer<void>? _disposed;
  int _nextId = 0;

  /// Arranca el isolate y carga el modelo. Lanza [TutorEngineException] si falla.
  static Future<LlamaWorker> start(WorkerLoad config) async {
    final fromWorker = ReceivePort();
    final handshake = Completer<SendPort>();
    late final LlamaWorker worker;
    final isolate = await Isolate.spawn(_workerMain, fromWorker.sendPort);
    fromWorker.listen((message) {
      if (!handshake.isCompleted) {
        handshake.complete(message as SendPort);
        return;
      }
      worker._onMessage(message as List<Object?>);
    });
    worker = LlamaWorker._(isolate, await handshake.future, fromWorker);
    worker._loading = Completer<void>();
    worker._toWorker.send(['load', config]);
    try {
      await worker._loading!.future;
    } catch (_) {
      await worker.dispose();
      rethrow;
    }
    return worker;
  }

  /// Genera la respuesta a [suffix] (historial y pregunta ya en ChatML) con
  /// [system] (el bloque de sistema ya en ChatML) como prefijo reutilizable.
  /// Devuelve el id de la generacion y sus piezas de texto.
  (int, Stream<String>) generate({
    required String system,
    required String suffix,
    required int maxTokens,
  }) {
    final id = _nextId++;
    final controller = StreamController<String>();
    _streams[id] = controller;
    _toWorker.send(['gen', id, system, suffix, maxTokens]);
    return (id, controller.stream);
  }

  /// Tokens del prompt de la generacion [id] (se consulta una vez, al terminar).
  int? promptTokensOf(int id) => _promptTokens.remove(id);

  /// Pide parar la generacion [id]; el worker la comprueba entre token y token.
  void stop(int id) => _toWorker.send(['stop', id]);

  Future<void> dispose() async {
    final done = _disposed = Completer<void>();
    _toWorker.send(['dispose']);
    await done.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    _fromWorker.close();
    _isolate.kill(priority: Isolate.immediate);
    for (final c in _streams.values) {
      if (!c.isClosed) c.close();
    }
    _streams.clear();
  }

  void _onMessage(List<Object?> m) {
    switch (m[0]) {
      case 'ready':
        _loading?.complete();
      case 'error':
        _loading?.completeError(TutorEngineException('No se pudo cargar el modelo: ${m[1]}'));
      case 'piece':
        final c = _streams[m[1] as int];
        if (c != null && !c.isClosed) c.add(m[2] as String);
      case 'prompt':
        _promptTokens[m[1] as int] = m[2] as int;
      case 'done':
        final c = _streams.remove(m[1] as int);
        if (c == null || c.isClosed) return;
        if (m[2] != true) c.addError(TutorEngineException('${m[3] ?? 'La generacion fallo.'}'));
        c.close();
      case 'disposed':
        _disposed?.complete();
    }
  }
}

void _workerMain(SendPort toMain) {
  final inbox = ReceivePort();
  toMain.send(inbox.sendPort);
  final worker = _Worker(toMain);
  inbox.listen((m) => worker.onMessage(m as List<Object?>));
}

class _Worker {
  _Worker(this._out);

  final SendPort _out;
  Llama? _llama;
  int _stopId = -1;

  /// Estado de la cache con el sistema procesado, y el texto al que corresponde
  /// (cambia con el grado).
  String? _prefixKey;
  Uint8List? _prefix;

  void onMessage(List<Object?> m) {
    switch (m[0]) {
      case 'load':
        _load(m[1] as WorkerLoad);
      case 'gen':
        _generate(m[1] as int, m[2] as String, m[3] as String, m[4] as int);
      case 'stop':
        _stopId = m[1] as int;
      case 'dispose':
        _dispose();
    }
  }

  void _load(WorkerLoad c) {
    try {
      _llama = Llama(
        c.path,
        modelParams: c.model,
        contextParams: c.context,
        samplerParams: c.sampler,
        verbose: c.verbose,
      );
      _out.send(['ready']);
    } catch (e) {
      _out.send(['error', '$e']);
    }
  }

  Future<void> _generate(int id, String system, String suffix, int maxTokens) async {
    final llama = _llama;
    if (llama == null) {
      _out.send(['done', id, false, 'El modelo no esta cargado.']);
      return;
    }
    final clock = Stopwatch()..start();
    var promptTokens = 0;
    // Contar es solo tokenizar (milisegundos); da la velocidad real del prompt.
    int count(String text) {
      try {
        return llama.tokenize(text, false).length;
      } catch (_) {
        return 0;
      }
    }

    try {
      promptTokens = count(suffix);
      if (system.isEmpty) {
        llama.clear();
        llama.setPrompt(suffix);
      } else {
        void buildPrefix() {
          promptTokens += count(system);
          llama.clear();
          llama.setPrompt(system);
          llama.getNextWithStatus(); // decodifica el prompt; el token muestreado no entra en la cache
          _prefix = llama.saveState();
          _prefixKey = system;
          if (kDebugMode) {
            debugPrint('[tutor] prefijo: ${_prefix!.length ~/ 1024} KB, ${clock.elapsedMilliseconds} ms');
          }
        }

        if (_prefix == null || _prefixKey != system) {
          buildPrefix(); // la cache ya queda con el prefijo
        } else {
          // Cada turno parte del prefijo limpio. No se vacia el contexto antes:
          // `loadState` calcula el tamaño esperado con el contenido actual de la
          // cache y un contexto vacio no admite el estado guardado.
          try {
            llama.loadState(_prefix!);
          } on RangeError {
            buildPrefix();
          }
        }
        // `setSlot` reinicia el muestreador (penalizacion de repeticion): la
        // respuesta no arrastra las palabras de la anterior.
        llama.setSlot('default');
        llama.setPrompt(suffix);
      }

      // Antes de la primera pieza: si la respuesta se corta, el dato ya esta.
      _out.send(['prompt', id, promptTokens]);
      var pieces = 0;
      while (true) {
        final (piece, done, limit) = llama.getNextWithStatus();
        if (piece.isNotEmpty) {
          _out.send(['piece', id, piece]);
          pieces++;
        }
        if (done || limit || pieces >= maxTokens) break;
        // Cede al bucle de eventos para atender un `stop` al instante.
        await Future<void>.delayed(Duration.zero);
        if (_stopId == id) break;
      }
      _out.send(['done', id, true, null]);
    } catch (e) {
      _out.send(['done', id, false, '$e']);
    }
  }

  void _dispose() {
    try {
      _llama?.dispose();
    } catch (_) {}
    _llama = null;
    _prefix = null;
    _out.send(['disposed']);
  }
}
