import 'package:equatable/equatable.dart';

/// Datos de rendimiento del tutor para que un padre pueda copiarlos y enviarlos
/// cuando el modelo va lento. No lleva datos personales (ni nombres ni preguntas).
class TutorDiagnostics extends Equatable {
  const TutorDiagnostics({
    this.model,
    this.modelGb,
    this.threads,
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
  });

  final String? model;
  final double? modelGb;
  final int? threads;
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

  bool get isEmpty => model == null;

  TutorDiagnostics withAnswer({
    required int firstPieceSeconds,
    required int pieces,
    required int totalSeconds,
    required double piecesPerSecond,
    int? promptChars,
  }) => TutorDiagnostics(
    model: model,
    modelGb: modelGb,
    threads: threads,
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
  );

  /// Valoracion en lenguaje claro: que esperar y que hacer.
  String? verdict() {
    if (isEmpty) return null;
    if (model!.toLowerCase().contains('7b')) {
      return 'El modelo de 7B es muy lento: puede tardar minutos por respuesta aunque el '
          'teléfono tenga mucha RAM. Prueba con el de 3B (o el de 1.5B).';
    }
    final rate = piecesPerSecond;
    final first = firstPieceSeconds;
    if (rate != null && rate < 3) {
      return 'Genera despacio (menos de 3 piezas/s): prueba con un modelo más pequeño o deja '
          'enfriar el teléfono.';
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
      'Hilos: ${threads ?? '-'} de ${cores ?? '-'} nucleos',
      'Frecuencia maxima por nucleo (MHz): ${mhz.isEmpty ? 'no disponible' : mhz.join(', ')}',
      'Modo bateria: ${batterySaver ? 'si' : 'no'}',
      'CPU segun llama.cpp: ${cpuFeatures ?? 'no disponible'}',
      'Variantes de CPU en la app: ${variants.isEmpty ? '-' : variants.join(', ')}',
    ];
    if (pieces != null) {
      lines.add(
        'Ultima respuesta: primera pieza a los $firstPieceSeconds s, $pieces piezas en '
        '$totalSeconds s (${piecesPerSecond!.toStringAsFixed(1)} piezas/s)'
        '${promptChars == null ? '' : ', prompt de $promptChars caracteres'}',
      );
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
  ];
}
