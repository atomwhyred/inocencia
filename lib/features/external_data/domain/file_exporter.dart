import 'package:equatable/equatable.dart';

/// Un archivo que el padre quiere pasar a otro dispositivo.
class ExportItem extends Equatable {
  const ExportItem({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;

  @override
  List<Object?> get props => [path, sizeBytes];
}

/// Avance de una copia: [doneBytes] de [totalBytes] entre todos los archivos.
class CopyProgress extends Equatable {
  const CopyProgress({
    required this.doneBytes,
    required this.totalBytes,
    required this.fileName,
    required this.fileIndex,
    required this.fileCount,
  });

  final int doneBytes;
  final int totalBytes;

  /// Archivo que se esta copiando y su posicion (1 de [fileCount]).
  final String fileName;
  final int fileIndex;
  final int fileCount;

  double get fraction => totalBytes == 0 ? 1 : (doneBytes / totalBytes).clamp(0.0, 1.0);

  @override
  List<Object?> get props => [doneBytes, totalBytes, fileName, fileIndex, fileCount];
}

/// Para parar una copia en curso desde la pantalla.
class CopyCancel {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Resultado de copiar: cuantos archivos llegaron enteros y, si no se completo,
/// por que (cancelada o error con mensaje para el padre).
class CopyResult extends Equatable {
  const CopyResult({required this.copied, this.cancelled = false, this.error});

  final int copied;
  final bool cancelled;
  final String? error;

  bool get ok => !cancelled && error == null;

  @override
  List<Object?> get props => [copied, cancelled, error];
}

/// Saca de la app los archivos que hacen falta (modelo, base de libros, PDF) para
/// pasarlos a otros dispositivos sin internet.
abstract class FileExporter {
  /// Abre el menu de compartir de Android (ShareIt, Zapya, Bluetooth...). Los
  /// archivos no se copian. `false` si no se pudo abrir.
  Future<bool> share(List<ExportItem> items, {String? title});

  /// Copia los archivos a [destDir] (otra carpeta, la tarjeta SD...) con progreso.
  /// Cada archivo se escribe como `.part` y solo se renombra al terminar, asi una
  /// copia cortada no deja un archivo roto con el nombre bueno.
  Future<CopyResult> copy(
    List<ExportItem> items,
    String destDir, {
    void Function(CopyProgress progress)? onProgress,
    CopyCancel? cancel,
  });
}
