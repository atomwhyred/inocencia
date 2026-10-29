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

  bool get isEmpty => model == null;

  TutorDiagnostics withAnswer({
    required int firstPieceSeconds,
    required int pieces,
    required int totalSeconds,
    required double piecesPerSecond,
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
  );

  /// Texto plano para copiar y pegar en un mensaje.
  String toReport() {
    final mhz = coreFreqsKhz.map((k) => (k / 1000).round()).toList();
    final lines = <String>[
      'inocencIA - diagnostico del tutor',
      'Modelo: ${model ?? '-'}${modelGb == null ? '' : ' (${modelGb!.toStringAsFixed(2)} GB)'}',
      'Hilos: ${threads ?? '-'} de ${cores ?? '-'} nucleos',
      'Frecuencia maxima por nucleo (MHz): ${mhz.isEmpty ? 'no disponible' : mhz.join(', ')}',
      'Modo bateria: ${batterySaver ? 'si' : 'no'}',
      'CPU segun llama.cpp: ${cpuFeatures ?? 'no disponible'}',
      'Variantes de CPU en la app: ${variants.isEmpty ? '-' : variants.join(', ')}',
    ];
    if (pieces != null) {
      lines.add(
        'Ultima respuesta: primera pieza a los $firstPieceSeconds s, $pieces piezas en '
        '$totalSeconds s (${piecesPerSecond!.toStringAsFixed(1)} piezas/s)',
      );
    } else {
      lines.add('Ultima respuesta: aun no hay ninguna');
    }
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
  ];
}
