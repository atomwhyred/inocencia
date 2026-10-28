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
///  - Qwen2.5-1.5B: algo mas rapido (~26 s por respuesta en un Pixel 6) pero con
///    fallos de fidelidad (llego a confundir respiracion con fotosintesis).
///  - Qwen2.5-3B: respuestas fieles al libro, algo mas lento (~32 s, hasta ~40 s
///    en turnos de seguimiento). Ver docs/models.md.
///  - Qwen2.5-7B: para telefonos de 12 GB. **Aun sin medir** en un telefono real.
class ModelRecommendation {
  const ModelRecommendation._();

  static const small = ModelOption(
    name: 'Qwen2.5-1.5B',
    fileName: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
    sizeBytes: 1117320736,
    summary: 'Más ligero, pero se equivoca más: revisa sus respuestas con el libro.',
  );

  static const large = ModelOption(
    name: 'Qwen2.5-3B',
    fileName: 'qwen2.5-3b-instruct-q4_k_m.gguf',
    sizeBytes: 2104932768,
    summary: 'Más fiel a los libros, pero tarda algo más en responder.',
  );

  static const xlarge = ModelOption(
    name: 'Qwen2.5-7B',
    fileName: 'qwen2.5-7b-instruct-q4_k_m.gguf',
    sizeBytes: 4683074240,
    summary: 'El más capaz con los libros, pero el más lento: pensado para teléfonos de 12 GB '
        '(aún sin medir).',
  );

  /// De menor a mayor.
  static const all = [small, large, xlarge];

  /// RAM minima (de las que informa Android, algo menor que la anunciada) para
  /// recomendar el modelo grande: 2,1 GB de modelo + contexto + el sistema.
  static const largeMinRamBytes = 7 * 1024 * 1024 * 1024;

  /// Un telefono de 12 GB informa ~11 GiB; uno de 10 GB, ~9,4 GiB. El de 7B
  /// ocupa 4,7 GB + contexto: con 10 GB queda poco margen, asi que no se
  /// recomienda ahi.
  static const xlargeMinRamBytes = 10 * 1024 * 1024 * 1024;

  /// Por debajo de esto ni el modelo pequeno va holgado.
  static const lowRamBytes = 3 * 1024 * 1024 * 1024;

  static ModelOption forRam(int totalRamBytes) {
    if (totalRamBytes >= xlargeMinRamBytes) return xlarge;
    return totalRamBytes >= largeMinRamBytes ? large : small;
  }

  /// Opcion mas ligera que [model] (la mas rapida si va justo de memoria); para
  /// el mas pequeno, el siguiente.
  static ModelOption alternativeTo(ModelOption model) {
    final i = all.indexOf(model);
    return i > 0 ? all[i - 1] : all[1];
  }

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
