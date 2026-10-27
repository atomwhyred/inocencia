import 'linked_file_status.dart';

abstract class ExternalFilesRepository {
  String? get modelPath;
  String? get knowledgePath;

  Future<void> setModelPath(String? path);
  Future<void> setKnowledgePath(String? path);

  /// Valida los dos archivos vinculados.
  Future<LinkedFilesStatus> check();

  /// Carpetas propias de la app (memoria interna y tarjeta SD) donde el padre
  /// puede copiar los archivos sin dar permisos especiales.
  Future<List<String>> appStorageDirs();

  /// Busca `.gguf` y `.db` dentro de las carpetas de la app.
  Future<List<DiscoveredFile>> discover({required List<String> extensions});

  /// Raices de almacenamiento para el explorador de rutas.
  Future<List<String>> browseRoots();

  /// Android 11+ exige un permiso especial para explorar fuera de la app.
  Future<bool> get needsAllFilesAccess;
  Future<bool> get hasAllFilesAccess;

  /// Abre los ajustes de Android; el resultado se comprueba al volver a la app.
  Future<void> requestAllFilesAccess();
}
