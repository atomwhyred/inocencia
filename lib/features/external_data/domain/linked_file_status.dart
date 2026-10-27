import 'package:equatable/equatable.dart';

/// Estado de un archivo externo vinculado (modelo GGUF o base de conocimiento).
enum LinkState {
  /// El padre aun no ha vinculado ninguna ruta.
  notLinked,

  /// Hay ruta guardada pero el archivo ya no existe o no se puede leer.
  missing,

  /// Existe pero no tiene el formato esperado.
  invalid,

  /// Listo para usarse.
  ready,
}

class LinkedFileStatus extends Equatable {
  const LinkedFileStatus({
    required this.state,
    this.path,
    this.sizeBytes,
    this.message,
  });

  const LinkedFileStatus.notLinked()
      : this(state: LinkState.notLinked);

  final LinkState state;
  final String? path;
  final int? sizeBytes;

  /// Explicacion corta para el padre ("Falta el archivo", "No es un GGUF"...).
  final String? message;

  bool get isReady => state == LinkState.ready;

  @override
  List<Object?> get props => [state, path, sizeBytes, message];
}

/// Estado de la base de conocimiento, con datos extra del `.db`.
class KnowledgeDbStatus extends LinkedFileStatus {
  const KnowledgeDbStatus({
    required super.state,
    super.path,
    super.sizeBytes,
    super.message,
    this.schemaVersion,
    this.chunkCount,
    this.grades = const [],
    this.subjects = const [],
  });

  const KnowledgeDbStatus.notLinked() : this(state: LinkState.notLinked);

  final String? schemaVersion;
  final int? chunkCount;

  /// Grados que contiene (0 = preescolar).
  final List<int> grades;
  final List<String> subjects;

  @override
  List<Object?> get props =>
      [...super.props, schemaVersion, chunkCount, grades, subjects];
}

/// Los dos archivos externos a la vez.
class LinkedFilesStatus extends Equatable {
  const LinkedFilesStatus({required this.model, required this.knowledge});

  final LinkedFileStatus model;
  final KnowledgeDbStatus knowledge;

  bool get allReady => model.isReady && knowledge.isReady;

  @override
  List<Object?> get props => [model, knowledge];
}

/// Archivo encontrado al escanear las carpetas de la app.
class DiscoveredFile extends Equatable {
  const DiscoveredFile({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;

  @override
  List<Object?> get props => [path, sizeBytes];
}
