import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../../../core/storage/untrusted_db.dart';

import '../../../core/constants.dart';
import '../domain/linked_file_status.dart';

/// Valida los archivos externos. Las versiones `*Sync` se pueden probar sin
/// isolates; las publicas las ejecutan fuera del hilo de la UI.
class ExternalFileValidator {
  const ExternalFileValidator();

  Future<LinkedFileStatus> validateModel(String? path) {
    if (path == null) return Future.value(const LinkedFileStatus.notLinked());
    return Isolate.run(() => validateModelSync(path));
  }

  Future<KnowledgeDbStatus> validateKnowledge(String? path) {
    if (path == null) return Future.value(const KnowledgeDbStatus.notLinked());
    return Isolate.run(() => validateKnowledgeSync(path));
  }

  /// Un GGUF empieza con los 4 bytes "GGUF" seguidos de la version (uint32 LE).
  static LinkedFileStatus validateModelSync(String path) {
    final file = File(path);
    final int size;
    try {
      if (!file.existsSync()) {
        return LinkedFileStatus(
          state: LinkState.missing,
          path: path,
          message: 'No se encuentra el archivo.',
        );
      }
      size = file.lengthSync();
    } on FileSystemException {
      return LinkedFileStatus(
        state: LinkState.missing,
        path: path,
        message: 'No se puede leer el archivo (revisa los permisos).',
      );
    }

    RandomAccessFile? raf;
    try {
      raf = file.openSync();
      final header = raf.readSync(8);
      final isGguf = header.length == 8 &&
          header[0] == 0x47 && // G
          header[1] == 0x47 && // G
          header[2] == 0x55 && // U
          header[3] == 0x46; // F
      final version = isGguf
          ? header[4] | (header[5] << 8) | (header[6] << 16) | (header[7] << 24)
          : 0;
      if (!isGguf || version < 1 || version > 3) {
        return LinkedFileStatus(
          state: LinkState.invalid,
          path: path,
          sizeBytes: size,
          message: 'No es un modelo GGUF valido.',
        );
      }
      return LinkedFileStatus(state: LinkState.ready, path: path, sizeBytes: size);
    } on FileSystemException {
      return LinkedFileStatus(
        state: LinkState.missing,
        path: path,
        message: 'No se puede leer el archivo (revisa los permisos).',
      );
    } finally {
      raf?.closeSync();
    }
  }

  /// La base debe tener `meta`, `chunks` y `chunks_fts` y una version de
  /// esquema soportada (ver docs/knowledge_db_schema.md).
  static KnowledgeDbStatus validateKnowledgeSync(String path) {
    final file = File(path);
    final int size;
    try {
      if (!file.existsSync()) {
        return KnowledgeDbStatus(
          state: LinkState.missing,
          path: path,
          message: 'No se encuentra el archivo.',
        );
      }
      size = file.lengthSync();
    } on FileSystemException {
      return KnowledgeDbStatus(
        state: LinkState.missing,
        path: path,
        message: 'No se puede leer el archivo (revisa los permisos).',
      );
    }

    Database? db;
    try {
      db = openUntrustedDb(path);
      final tables = db
          .select(
            // Solo tablas de verdad: una vista podría esconder una consulta sin fin.
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name IN ('meta','chunks','chunks_fts')",
          )
          .map((r) => r['name'] as String)
          .toSet();
      final missing = {'meta', 'chunks', 'chunks_fts'}.difference(tables);
      if (missing.isNotEmpty) {
        return KnowledgeDbStatus(
          state: LinkState.invalid,
          path: path,
          sizeBytes: size,
          message: 'Faltan tablas: ${missing.join(', ')}.',
        );
      }

      final versionRows =
          db.select("SELECT value FROM meta WHERE key = 'schema_version'");
      final version =
          versionRows.isEmpty ? null : versionRows.first['value']?.toString();
      if (version != supportedKnowledgeSchemaVersion) {
        return KnowledgeDbStatus(
          state: LinkState.invalid,
          path: path,
          sizeBytes: size,
          schemaVersion: version,
          message: 'Version de esquema no soportada '
              '(${version ?? 'desconocida'}; se espera $supportedKnowledgeSchemaVersion).',
        );
      }

      final count = db.select('SELECT COUNT(*) AS n FROM chunks').first['n'] as int;
      final grades = db
          .select('SELECT DISTINCT grade FROM chunks ORDER BY grade')
          .map((r) => r['grade'] as int)
          .toList();
      final subjects = db
          .select('SELECT DISTINCT subject FROM chunks ORDER BY subject')
          .map((r) => r['subject'] as String)
          .toList();
      return KnowledgeDbStatus(
        state: LinkState.ready,
        path: path,
        sizeBytes: size,
        schemaVersion: version,
        chunkCount: count,
        grades: grades,
        subjects: subjects,
      );
    } on SqliteException catch (e) {
      return KnowledgeDbStatus(
        state: LinkState.invalid,
        path: path,
        sizeBytes: size,
        message: 'No es una base de conocimiento valida (${e.message}).',
      );
    } on Object {
      // Tipos inesperados en las columnas (una base manipulada o de otra app).
      return KnowledgeDbStatus(
        state: LinkState.invalid,
        path: path,
        sizeBytes: size,
        message: 'No es una base de conocimiento valida (datos con un formato inesperado).',
      );
    } finally {
      db?.close();
    }
  }
}
