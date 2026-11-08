import 'package:path/path.dart' as p;

/// Modelo GGUF que la app sabe usar (probado en un telefono real).
class ModelOption {
  const ModelOption({
    required this.name,
    required this.fileName,
    required this.sizeBytes,
    required this.summary,
    this.otherFileNames = const [],
  });

  final String name;

  /// Nombre del archivo recomendado en Hugging Face.
  final String fileName;

  /// Otras cuantizaciones del mismo modelo que la app tambien reconoce.
  final List<String> otherFileNames;
  final int sizeBytes;

  /// Que ofrece y que cuesta, en una frase para el padre.
  final String summary;
}

/// Catalogo y recomendacion segun la RAM del telefono.
///
/// Solo figuran modelos probados con el tutor:
///  - Qwen2.5-1.5B: algo mas rapido (~26 s por respuesta en un Pixel 6) pero con
///    fallos de fidelidad (llego a confundir respiracion con fotosintesis).
///  - Qwen2.5-3B: respuestas fieles al libro. Se recomienda en Q4_0: en un Pixel 6
///    empieza a responder en ~9-12 s frente a ~17-25 s del Q4_K_M (llama.cpp
///    reempaqueta Q4_0 para dotprod), con calidad parecida en 8 preguntas de 4.º.
///    El Q4_K_M se sigue reconociendo. Ver docs/models.md.
///  - Qwen2.5-7B: opcional y **no se recomienda**: en un Xiaomi 17T Pro (12 GB) tardaba
///    de 1 a 3 minutos por respuesta. Cabe en 12 GB, pero RAM no es velocidad.
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
    fileName: 'qwen2.5-3b-instruct-q4_0.gguf',
    otherFileNames: ['qwen2.5-3b-instruct-q4_k_m.gguf'],
    sizeBytes: 1997879712,
    summary: 'Más fiel a los libros. Empieza a responder en unos 10 segundos.',
  );

  static const xlarge = ModelOption(
    name: 'Qwen2.5-7B',
    fileName: 'qwen2.5-7b-instruct-q4_k_m.gguf',
    sizeBytes: 4683074240,
    summary:
        'Opcional: el más capaz, pero el más lento. Puede tardar minutos por respuesta '
        'aunque el teléfono tenga 12 GB de RAM.',
  );

  /// De menor a mayor.
  static const all = [small, large, xlarge];

  /// RAM minima (de las que informa Android, algo menor que la anunciada) para
  /// recomendar el modelo grande: 2,1 GB de modelo + contexto + el sistema.
  static const largeMinRamBytes = 7 * 1024 * 1024 * 1024;

  /// Por debajo de esto ni el modelo pequeno va holgado.
  static const lowRamBytes = 3 * 1024 * 1024 * 1024;

  /// Modelo recomendado. El de 7B nunca: la RAM decide si cabe, no si va rapido.
  static ModelOption forRam(int totalRamBytes) => totalRamBytes >= largeMinRamBytes ? large : small;

  /// `true` si [model] tarda minutos por respuesta en la mayoria de telefonos.
  static bool isSlow(ModelOption model) => model == xlarge;

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
      if (name == m.fileName || m.otherFileNames.contains(name)) return m;
    }
    return null;
  }
}
