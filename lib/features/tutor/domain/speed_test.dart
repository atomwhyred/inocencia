import 'package:equatable/equatable.dart';

/// Que mide cada muestra de la prueba de velocidad.
enum SpeedKind {
  /// Leer el texto (el libro y la pregunta): marca el tiempo hasta la primera pieza.
  prompt,

  /// Escribir la respuesta pieza a pieza.
  generation,
}

/// Una medida: [tokens] en [millis] con [threads] hilos.
class SpeedSample extends Equatable {
  const SpeedSample({
    required this.kind,
    required this.threads,
    required this.tokens,
    required this.millis,
  });

  factory SpeedSample.fromJson(Map<String, Object?> j) => SpeedSample(
    kind: SpeedKind.values.byName(j['kind'] as String),
    threads: j['threads'] as int,
    tokens: j['tokens'] as int,
    millis: j['millis'] as int,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'threads': threads,
    'tokens': tokens,
    'millis': millis,
  };

  final SpeedKind kind;
  final int threads;
  final int tokens;
  final int millis;

  double get tokensPerSecond => millis <= 0 ? 0 : tokens * 1000 / millis;

  @override
  List<Object?> get props => [kind, threads, tokens, millis];
}

/// Que combinaciones se prueban en un telefono de [cores] nucleos.
class SpeedPlan {
  const SpeedPlan({required this.generation, required this.prompt});

  /// Hilos al escribir: de 2 a 6. Hilos al leer: 4, 6 y 8 (los que quepan).
  factory SpeedPlan.forCores(int cores) {
    final gen = [for (var n = 2; n <= 6; n++) if (n <= cores) n];
    final prompt = [for (final n in const [4, 6, 8]) if (n <= cores) n];
    return SpeedPlan(
      generation: gen.isEmpty ? const [1] : gen,
      prompt: prompt.isEmpty ? [gen.isEmpty ? 1 : gen.last] : prompt,
    );
  }

  final List<int> generation;
  final List<int> prompt;

  /// Cada combinacion se mide dos veces (en orden y al reves), para que el calor
  /// o una tarea de Android no favorezcan a la primera o a la ultima.
  static const passes = 2;

  int get steps => passes * (generation.length + prompt.length);
}

/// Resultado de la prueba: la tabla y la combinacion mas rapida.
class SpeedTestResult extends Equatable {
  const SpeedTestResult({required this.samples, this.cpuCompat = false, this.thermal});

  factory SpeedTestResult.fromJson(Map<String, Object?> j) => SpeedTestResult(
    samples: [
      for (final s in (j['samples'] as List? ?? const []))
        SpeedSample.fromJson((s as Map).cast<String, Object?>()),
    ],
    cpuCompat: j['cpuCompat'] as bool? ?? false,
    thermal: j['thermal'] as int?,
  );

  Map<String, Object?> toJson() => {
    'samples': [for (final s in samples) s.toJson()],
    'cpuCompat': cpuCompat,
    'thermal': thermal,
  };

  final List<SpeedSample> samples;

  /// Si se hizo con la CPU en modo compatible (sin SVE/SME).
  final bool cpuCompat;

  /// Estado termico de Android al terminar (ver [thermalLabel]).
  final int? thermal;

  /// Diferencias menores que esta se toman como empate: gana el que usa menos
  /// hilos (calienta menos y deja nucleos libres).
  static const tieShare = 0.05;

  /// La mejor medida de cada numero de hilos, de menos a mas hilos.
  List<SpeedSample> of(SpeedKind kind) {
    final best = <int, SpeedSample>{};
    for (final s in samples) {
      if (s.kind != kind) continue;
      final prev = best[s.threads];
      if (prev == null || s.tokensPerSecond > prev.tokensPerSecond) best[s.threads] = s;
    }
    return best.values.toList()..sort((a, b) => a.threads.compareTo(b.threads));
  }

  int? _best(SpeedKind kind) {
    SpeedSample? best;
    for (final s in of(kind)) {
      if (best == null || s.tokensPerSecond > best.tokensPerSecond * (1 + tieShare)) best = s;
    }
    return best?.threads;
  }

  int? get bestGeneration => _best(SpeedKind.generation);
  int? get bestPrompt => _best(SpeedKind.prompt);

  bool get isComplete => bestGeneration != null && bestPrompt != null;

  /// Texto para el diagnostico que se copia.
  String toReport() {
    String row(SpeedSample s) =>
        '  ${s.threads} hilos: ${s.tokensPerSecond.toStringAsFixed(1)} tokens/s';
    return [
      'Prueba de velocidad${cpuCompat ? ' (CPU en modo compatible)' : ''}'
          '${thermal == null ? '' : ', temperatura: ${thermalLabel(thermal!)}'}:',
      ' Escribir la respuesta:',
      for (final s in of(SpeedKind.generation)) row(s),
      ' Leer el texto:',
      for (final s in of(SpeedKind.prompt)) row(s),
      if (isComplete) ' Mejor: $bestGeneration hilos al escribir, $bestPrompt al leer',
    ].join('\n');
  }

  @override
  List<Object?> get props => [samples, cpuCompat, thermal];
}

/// Estado termico de Android (`PowerManager.THERMAL_STATUS_*`) en palabras.
String thermalLabel(int status) => switch (status) {
  0 => 'normal',
  1 => 'algo caliente',
  2 => 'caliente (Android empieza a frenar)',
  3 => 'muy caliente (Android frena mucho)',
  _ => 'demasiado caliente',
};

/// Hilos elegidos con la prueba; sustituyen a los automaticos al cargar el modelo.
class ThreadOverride extends Equatable {
  const ThreadOverride({required this.generation, required this.prompt});

  final int generation;
  final int prompt;

  @override
  List<Object?> get props => [generation, prompt];
}

/// Motor que puede hacer la prueba de velocidad (el real usa llama.cpp).
abstract class SpeedTester {
  Future<void> load(String modelPath);

  /// Una muestra por combinacion de [plan]; cancelar la suscripcion la detiene.
  Stream<SpeedSample> speedTest(SpeedPlan plan);

  Future<void> dispose();
}
