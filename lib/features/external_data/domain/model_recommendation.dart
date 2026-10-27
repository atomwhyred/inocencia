import 'package:path/path.dart' as p;

/// Modelo GGUF que la app sabe usar (probado en un telefono real).
class ModelOption {
  const ModelOption({
    required this.name,
    required this.fileName,
    required this.sizeBytes,
    required this.summary,
  });

  final String name;

  /// Nombre del archivo Q4_K_M en Hugging Face.
  final String fileName;
  final int sizeBytes;

  /// Que ofrece y que cuesta, en una frase para el padre.
  final String summary;
}

/// Catalogo y recomendacion segun la RAM del telefono.
///
/// Solo figuran modelos probados con el tutor:
///  - Qwen2.5-1.5B: va rapido (~20 s por respuesta en un Pixel 6) pero con
///    fallos de fidelidad (llego a confundir respiracion con fotosintesis).
///  - Qwen2.5-3B: respuestas fieles al libro, pero el doble de lento (~50 s).
class ModelRecommendation {
  const ModelRecommendation._();

  static const small = ModelOption(
    name: 'Qwen2.5-1.5B',
    fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    sizeBytes: 1117320736,
    summary: 'Rápido y ligero, pero se equivoca más: revisa sus respuestas con el libro.',
  );

  static const large = ModelOption(
    name: 'Qwen2.5-3B',
    fileName: 'qwen2.5-3b-instruct-q4_k_m.gguf',
    sizeBytes: 2104932768,
    summary: 'Más fiel a los libros, pero tarda el doble en responder.',
  );

  static const all = [small, large];

  /// RAM minima (de las que informa Android, algo menor que la anunciada) para
  /// recomendar el modelo grande: 2,1 GB de modelo + contexto + el sistema.
  static const largeMinRamBytes = 7 * 1024 * 1024 * 1024;

  /// Por debajo de esto ni el modelo pequeno va holgado.
  static const lowRamBytes = 3 * 1024 * 1024 * 1024;

  static ModelOption forRam(int totalRamBytes) =>
      totalRamBytes >= largeMinRamBytes ? large : small;

  static bool isLowRam(int totalRamBytes) => totalRamBytes < lowRamBytes;

  /// Modelo conocido al que corresponde el archivo vinculado, si es uno del catalogo.
  static ModelOption? identify(String? path) {
    if (path == null) return null;
    final name = p.basename(path).toLowerCase();
    for (final m in all) {
      if (name == m.fileName) return m;
    }
    return null;
  }
}
