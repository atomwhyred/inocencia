import 'package:equatable/equatable.dart';

import 'speed_test.dart';

/// Datos de rendimiento del tutor para que un padre pueda copiarlos y enviarlos
/// cuando el modelo va lento. No lleva datos personales (ni nombres ni preguntas).
class TutorDiagnostics extends Equatable {
  const TutorDiagnostics({
    this.model,
    this.modelGb,
    this.threads,
    this.batchThreads,
    this.cores,
    this.coreFreqsKhz = const [],
    this.variants = const [],
    this.cpuFeatures,
    this.batterySaver = false,
    this.firstPieceSeconds,
    this.pieces,
    this.totalSeconds,
    this.piecesPerSecond,
    this.promptChars,
    this.promptTokens,
    this.threadsTuned = false,
    this.cpuCompat = false,
    this.backgrounded = false,
    this.thermalStart,
    this.thermalEnd,
  });

  /// Lee lo guardado por [toJson]; con datos ilegibles, un diagnostico vacio.
  factory TutorDiagnostics.fromJson(Map<String, Object?> j) {
    try {
      return TutorDiagnostics(
        model: j['model'] as String?,
        modelGb: (j['modelGb'] as num?)?.toDouble(),
        threads: j['threads'] as int?,
        batchThreads: j['batchThreads'] as int?,
        cores: j['cores'] as int?,
        coreFreqsKhz: [for (final f in (j['coreFreqsKhz'] as List?) ?? const []) f as int],
        variants: [for (final v in (j['variants'] as List?) ?? const []) v as String],
        cpuFeatures: j['cpuFeatures'] as String?,
        batterySaver: j['batterySaver'] as bool? ?? false,
        firstPieceSeconds: j['firstPieceSeconds'] as int?,
        pieces: j['pieces'] as int?,
        totalSeconds: j['totalSeconds'] as int?,
        piecesPerSecond: (j['piecesPerSecond'] as num?)?.toDouble(),
        promptChars: j['promptChars'] as int?,
        promptTokens: j['promptTokens'] as int?,
        threadsTuned: j['threadsTuned'] as bool? ?? false,
        cpuCompat: j['cpuCompat'] as bool? ?? false,
        backgrounded: j['backgrounded'] as bool? ?? false,
        thermalStart: j['thermalStart'] as int?,
        thermalEnd: j['thermalEnd'] as int?,
      );
    } catch (_) {
      return const TutorDiagnostics();
    }
  }

  Map<String, Object?> toJson() => {
    'model': model,
    'modelGb': modelGb,
    'threads': threads,
    'batchThreads': batchThreads,
    'cores': cores,
    'coreFreqsKhz': coreFreqsKhz,
    'variants': variants,
    'cpuFeatures': cpuFeatures,
    'batterySaver': batterySaver,
    'firstPieceSeconds': firstPieceSeconds,
    'pieces': pieces,
    'totalSeconds': totalSeconds,
    'piecesPerSecond': piecesPerSecond,
    'promptChars': promptChars,
    'promptTokens': promptTokens,
    'threadsTuned': threadsTuned,
    'cpuCompat': cpuCompat,
    'backgrounded': backgrounded,
    'thermalStart': thermalStart,
    'thermalEnd': thermalEnd,
  };

  final String? model;
  final double? modelGb;
  /// Hilos al generar y al procesar el prompt (pueden ser mas en chips con nucleos
  /// medianos fuertes).
  final int? threads;
  final int? batchThreads;
  final int? cores;
  final List<int> coreFreqsKhz;

  /// `libggml-cpu-*.so` que trae la app.
  final List<String> variants;

  /// Funciones de CPU que llama.cpp ve (`NEON = 1 | DOTPROD = 1 ...`).
  final String? cpuFeatures;
  final bool batterySaver;

  /// Ultima respuesta generada.
  final int? firstPieceSeconds;
  final int? pieces;
  final int? totalSeconds;
  final double? piecesPerSecond;

  /// Caracteres del prompt de la ultima respuesta (instrucciones + libro + historial).
  final int? promptChars;

  /// Tokens procesados antes de la primera pieza.
  final int? promptTokens;

  /// Hilos elegidos por la prueba de velocidad (no los automaticos).
  final bool threadsTuned;

  /// CPU en modo compatible (variante sin SVE/SME).
  final bool cpuCompat;

  /// La app salio de la pantalla durante la ultima respuesta: la medida no vale.
  final bool backgrounded;

  /// Estado termico de Android al empezar y al acabar la ultima respuesta.
  final int? thermalStart;
  final int? thermalEnd;

  /// Tokens del prompt por segundo (aproximado: incluye el muestreo de la primera pieza).
  double? get promptTokensPerSecond {
    final t = promptTokens, s = firstPieceSeconds;
    if (t == null || t <= 0 || s == null) return null;
    return t / (s < 1 ? 1 : s);
  }

  bool get isEmpty => model == null;

  TutorDiagnostics withAnswer({
    required int firstPieceSeconds,
    required int pieces,
    required int totalSeconds,
    required double piecesPerSecond,
    int? promptChars,
    int? promptTokens,
    bool backgrounded = false,
    int? thermalStart,
    int? thermalEnd,
  }) => TutorDiagnostics(
    model: model,
    modelGb: modelGb,
    threads: threads,
    batchThreads: batchThreads,
    cores: cores,
    coreFreqsKhz: coreFreqsKhz,
    variants: variants,
    cpuFeatures: cpuFeatures,
    batterySaver: batterySaver,
    firstPieceSeconds: firstPieceSeconds,
    pieces: pieces,
    totalSeconds: totalSeconds,
    piecesPerSecond: piecesPerSecond,
    promptChars: promptChars,
    promptTokens: promptTokens,
    threadsTuned: threadsTuned,
    cpuCompat: cpuCompat,
    backgrounded: backgrounded,
    thermalStart: thermalStart,
    thermalEnd: thermalEnd,
  );

  /// Valoracion en lenguaje claro: que esperar y que hacer.
  String? verdict() {
    if (isEmpty) return null;
    if (model!.toLowerCase().contains('7b')) {
      return 'El modelo de 7B es muy lento: puede tardar minutos por respuesta aunque el '
          'teléfono tenga mucha RAM. Prueba con el de 3B (o el de 1.5B).';
    }
    if (backgrounded) {
      return 'Medida no válida: la app salió de la pantalla mientras respondía y Android la frenó. '
          'Repite la pregunta sin salir de la app, o usa la prueba de velocidad.';
    }
    final rate = piecesPerSecond;
    final first = firstPieceSeconds;
    if (rate != null && rate < 3) {
      if ((thermalEnd ?? 0) >= 2) {
        return 'Genera despacio porque el teléfono está caliente y Android lo frena: déjalo enfriar.';
      }
      return 'Genera despacio (menos de 3 piezas/s): haz la prueba de velocidad para que la app '
          'busque la mejor configuración de este teléfono.';
    }
    if (first != null && first > 30) {
      return 'Genera bien, pero tarda en empezar (${first}s procesando el libro). Es normal con el '
          'modelo de 3B en teléfonos modestos.';
    }
    if (pieces != null) return 'Velocidad normal.';
    return null;
  }

  /// Texto plano para copiar y pegar en un mensaje.
  String toReport({int? ramBytes}) {
    final mhz = coreFreqsKhz.map((k) => (k / 1000).round()).toList();
    final lines = <String>[
      'inocencIA - diagnostico del tutor',
      'Modelo: ${model ?? '-'}${modelGb == null ? '' : ' (${modelGb!.toStringAsFixed(2)} GB)'}',
      if (ramBytes != null)
        'RAM del dispositivo: ${(ramBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB',
      'Hilos: ${threads ?? '-'} de ${cores ?? '-'} nucleos'
          '${batchThreads == null || batchThreads == threads ? '' : ' ($batchThreads para el prompt)'}'
          '${threadsTuned ? ', elegidos por la prueba de velocidad' : ''}',
      'Frecuencia maxima por nucleo (MHz): ${mhz.isEmpty ? 'no disponible' : mhz.join(', ')}',
      'Modo bateria: ${batterySaver ? 'si' : 'no'}',
      'CPU segun llama.cpp: ${cpuFeatures ?? 'no disponible'}',
      'Variantes de CPU en la app: ${variants.isEmpty ? '-' : variants.join(', ')}',
      if (cpuCompat) 'CPU en modo compatible: si (sin SVE/SME)',
    ];
    if (pieces != null) {
      lines.add(
        'Ultima respuesta: primera pieza a los $firstPieceSeconds s, $pieces piezas en '
        '$totalSeconds s (${piecesPerSecond!.toStringAsFixed(1)} piezas/s)'
        '${promptChars == null ? '' : ', prompt de $promptChars caracteres'}'
        '${promptTokensPerSecond == null ? '' : ' ($promptTokens tokens, '
            '${promptTokensPerSecond!.toStringAsFixed(1)} tokens/s)'}',
      );
      if (backgrounded) lines.add('La app salio de la pantalla durante la respuesta');
      if (thermalStart != null || thermalEnd != null) {
        lines.add(
          'Temperatura: ${thermalStart == null ? '-' : thermalLabel(thermalStart!)} al empezar, '
          '${thermalEnd == null ? '-' : thermalLabel(thermalEnd!)} al acabar',
        );
      }
    } else {
      lines.add('Ultima respuesta: aun no hay ninguna');
    }
    final v = verdict();
    if (v != null) lines.add('Valoracion: $v');
    return lines.join('\n');
  }

  @override
  List<Object?> get props => [
    model,
    modelGb,
    threads,
    cores,
    coreFreqsKhz,
    variants,
    cpuFeatures,
    batterySaver,
    firstPieceSeconds,
    pieces,
    totalSeconds,
    piecesPerSecond,
    promptChars,
    promptTokens,
    threadsTuned,
    cpuCompat,
    backgrounded,
    thermalStart,
    thermalEnd,
  ];
}
