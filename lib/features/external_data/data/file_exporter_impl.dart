import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/storage/platform_info.dart';
import '../../../core/utils/format_bytes.dart';
import '../domain/file_exporter.dart';

class FileExporterImpl implements FileExporter {
  FileExporterImpl({
    Future<int?> Function(String path)? freeBytes,
    Future<bool> Function(List<String> paths, String? title)? shareFiles,
    this.chunkBytes = 1024 * 1024,
  })  : _freeBytes = freeBytes ?? const PlatformInfo().freeBytes,
        _shareFiles =
            shareFiles ?? ((paths, title) => const PlatformInfo().shareFiles(paths, title: title));

  final Future<int?> Function(String path) _freeBytes;
  final Future<bool> Function(List<String> paths, String? title) _shareFiles;

  /// Tamano de cada bloque leido y escrito: es tambien cada cuanto se avisa del
  /// progreso y se mira si el padre cancelo.
  final int chunkBytes;

  /// Margen que debe sobrar en el destino, para no dejarlo al limite.
  static const spareBytes = 32 * 1024 * 1024;

  @override
  Future<bool> share(List<ExportItem> items, {String? title}) {
    final paths = [for (final i in items) if (File(i.path).existsSync()) i.path];
    if (paths.isEmpty) return Future.value(false);
    return _shareFiles(paths, title);
  }

  @override
  Future<CopyResult> copy(
    List<ExportItem> items,
    String destDir, {
    void Function(CopyProgress progress)? onProgress,
    CopyCancel? cancel,
  }) async {
    if (items.isEmpty) return const CopyResult(copied: 0);
    final dir = Directory(destDir);
    if (!dir.existsSync()) {
      return const CopyResult(copied: 0, error: 'La carpeta de destino no existe.');
    }
    // Copiar un archivo sobre si mismo lo vaciaria.
    for (final i in items) {
      if (p.equals(p.join(destDir, p.basename(i.path)), i.path)) {
        return const CopyResult(
          copied: 0,
          error: 'El destino es la misma carpeta de origen: elige otra.',
        );
      }
    }

    // El tamano real manda: el del catalogo puede haber cambiado.
    final sizes = [for (final i in items) File(i.path).lengthSync()];
    final total = sizes.fold<int>(0, (a, b) => a + b);
    final free = await _freeBytes(destDir);
    if (free != null && free < total + spareBytes) {
      return CopyResult(
        copied: 0,
        error: 'No hay espacio suficiente en el destino: hacen falta ${formatBytes(total)} '
            'y hay ${formatBytes(free)} libres.',
      );
    }

    var done = 0;
    var copied = 0;
    for (var n = 0; n < items.length; n++) {
      final src = File(items[n].path);
      final name = p.basename(src.path);
      final dest = p.join(destDir, name);
      final part = File('$dest.part');
      try {
        final finished = await _copyFile(src, part, sizes[n], cancel, (bytes) {
          done += bytes;
          onProgress?.call(CopyProgress(
            doneBytes: done,
            totalBytes: total,
            fileName: name,
            fileIndex: n + 1,
            fileCount: items.length,
          ));
        });
        if (!finished) {
          if (part.existsSync()) part.deleteSync();
          return CopyResult(copied: copied, cancelled: true);
        }
        await part.rename(dest);
        copied++;
      } on FileSystemException catch (e) {
        if (part.existsSync()) part.deleteSync();
        return CopyResult(
          copied: copied,
          error: 'No se pudo copiar $name: ${e.osError?.message ?? e.message}.',
        );
      }
    }
    return CopyResult(copied: copied);
  }

  /// Copia [src] en [part] por bloques. `false` si se cancelo a medias.
  Future<bool> _copyFile(
    File src,
    File part,
    int size,
    CopyCancel? cancel,
    void Function(int bytes) onBytes,
  ) async {
    final input = await src.open();
    try {
      final output = await part.open(mode: FileMode.write);
      try {
        var done = 0;
        while (done < size) {
          if (cancel?.isCancelled ?? false) return false;
          final chunk = await input.read(chunkBytes);
          if (chunk.isEmpty) break;
          await output.writeFrom(chunk);
          done += chunk.length;
          onBytes(chunk.length);
        }
        return true;
      } finally {
        await output.close();
      }
    } finally {
      await input.close();
    }
  }
}
