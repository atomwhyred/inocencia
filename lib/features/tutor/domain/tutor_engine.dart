import 'tutor_prompt.dart';

/// Motor de lenguaje local. La implementacion real usa llama.cpp; en las
/// pruebas se sustituye por uno falso.
abstract class TutorEngine {
  /// Carga el modelo GGUF (varios segundos). Lanza si el archivo no sirve.
  Future<void> load(String modelPath);

  bool get isLoaded;

  /// Genera la respuesta pieza a pieza. El stream termina al acabar; cancelar
  /// la suscripcion detiene la generacion.
  Stream<String> generate(List<ChatTurn> turns);

  /// Libera el modelo y su memoria.
  Future<void> dispose();
}

class TutorEngineException implements Exception {
  const TutorEngineException(this.message);
  final String message;

  @override
  String toString() => message;
}
